import AVFoundation
import Combine
import LiveKit

@MainActor
final class AudioRoomManager: ObservableObject {
    enum State: Equatable { case idle, connecting, connected, reconnecting, failed(String) }

    @Published private(set) var state: State = .idle
    @Published private(set) var participants: [ParticipantInfo] = []   // local participant first
    @Published private(set) var isMicEnabled = true
    @Published private(set) var isDeafened = false                     // all remote audio muted
    @Published private(set) var headphonesConnected = false            // false → UI shows a warning
    @Published private(set) var micLevel: Float = 0                    // own mic level 0…1, before the gate

    private var room: Room?
    private let gate = NoiseGate()
    private var levelTimer: Timer?
    // Room holds its delegates weakly, so we keep the observer alive here.
    private lazy var observer = RoomObserver { [weak self] room in
        Task { @MainActor [weak self] in self?.refresh(room) }
    }

    init() {
        headphonesConnected = Self.isHeadphoneRoute()
        let center = NotificationCenter.default
        // The manager lives for the whole app, so these observers are never removed.
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleRouteChange() }
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in self?.handleInterruption(rawType) }
        }
    }

    func join(code: String, name: String) async {
        guard room == nil else { return }
        let sandboxID = (Bundle.main.object(forInfoDictionaryKey: "LKSandboxID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !sandboxID.isEmpty else {
            state = .failed("LiveKit token server ID is missing (Info.plist key LKSandboxID).")
            return
        }

        state = .connecting
        let room = Room(delegate: observer)
        self.room = room
        do {
            // We own the session: the SDK's automatic setup would switch to .voiceChat, which ducks the game and forces HFP.
            AudioManager.shared.audioSession.isAutomaticConfigurationEnabled = false
            // Apple voice processing (VPIO) brings back ducking and HFP, so WebRTC's software processing is used instead.
            try AudioManager.shared.setPlatformVoiceProcessingAllowed(false)
            AudioManager.shared.capturePostProcessingDelegate = gate
            try configureSession()

            let details = try await DevelopmentTokenSource(id: sandboxID)
                .fetch(TokenRequestOptions(roomName: code, participantName: name))
            try await room.connect(url: details.serverURL.absoluteString, token: details.participantToken)
            if isMicEnabled {
                try await room.localParticipant.setMicrophone(enabled: true)
            }
            guard self.room === room else { return } // leave() was called while joining
            state = .connected
            startLevelTimer()
            refresh(room)
        } catch {
            guard self.room === room else { return }
            self.room = nil
            await room.disconnect()
            tearDown()
            state = .failed(error.localizedDescription)
        }
    }

    func leave() async {
        let room = self.room
        self.room = nil
        await room?.disconnect()
        tearDown()
        state = .idle
    }

    func setMicEnabled(_ enabled: Bool) async {
        isMicEnabled = enabled
        guard let room else { return }
        do {
            try await room.localParticipant.setMicrophone(enabled: enabled)
        } catch {
            isMicEnabled = room.localParticipant.isMicrophoneEnabled()
        }
        refresh(room)
    }

    func setDeafened(_ deafened: Bool) {
        isDeafened = deafened
        // The main mixer carries every remote track's playout and the SDK reapplies this value
        // when the engine restarts, so it also covers participants who join later.
        AudioManager.shared.mixer.outputVolume = deafened ? 0 : 1
    }

    /// Per-listener volume for one remote participant (1.0 = 100%, 0…2). Applied immediately and remembered.
    func setVolume(_ volume: Double, for id: String) {
        guard let index = participants.firstIndex(where: { $0.id == id }) else { return }
        let clamped = min(max(volume, 0), 2)
        participants[index].volume = clamped
        // Keyed by name: the development token server hands out a new random identity on every join.
        UserDefaults.standard.set(clamped, forKey: Self.volumeKey(participants[index].name))
        if let room { refresh(room) }
    }

    private static func volumeKey(_ name: String) -> String { "volume." + name }

    private static func savedVolume(_ name: String) -> Double {
        UserDefaults.standard.object(forKey: volumeKey(name)) as? Double ?? 1
    }

    // MARK: - Audio session

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        // .playAndRecord: we need the mic. Mode .default (not .voiceChat): no ducking of the game, no forced HFP.
        // .mixWithOthers: the game's audio keeps playing alongside ours.
        // .allowBluetoothA2DP: headphones stay in high-quality A2DP; .allowBluetooth is never set because it enables HFP.
        try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetoothA2DP])
        try session.setActive(true)
        preferBuiltInMic()
    }

    // A2DP has no microphone, so input must come from the phone's built-in mic.
    private func preferBuiltInMic() {
        let session = AVAudioSession.sharedInstance()
        guard session.preferredInput?.portType != .builtInMic,
              let mic = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else { return }
        try? session.setPreferredInput(mic)
    }

    // The gate measures on the audio thread; the UI polls it at 10 Hz instead of being pushed every 10 ms.
    private func startLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let level = self.isMicEnabled ? self.gate.level : 0
                if abs(level - self.micLevel) > 0.02 { self.micLevel = level }
            }
        }
    }

    private func tearDown() {
        levelTimer?.invalidate()
        levelTimer = nil
        micLevel = 0
        participants = []
        // Tells the game (and other apps) they can take the audio back fully.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handleRouteChange() {
        // iOS can switch input on a route change (e.g. headset plugged in), so pin the built-in mic again.
        if room != nil { preferBuiltInMic() }
        headphonesConnected = Self.isHeadphoneRoute()
    }

    private func handleInterruption(_ rawType: UInt?) {
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            // iOS has already paused our audio (e.g. a phone call); nothing to do until it ends.
            break
        case .ended:
            guard let room else { return }
            // iOS does not reactivate the session for us after an interruption.
            try? AVAudioSession.sharedInstance().setActive(true)
            Task { try? await room.localParticipant.setMicrophone(enabled: isMicEnabled) }
        @unknown default:
            break
        }
    }

    private static func isHeadphoneRoute() -> Bool {
        let headphonePorts: [AVAudioSession.Port] = [.headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP]
        return AVAudioSession.sharedInstance().currentRoute.outputs.contains { headphonePorts.contains($0.portType) }
    }

    // MARK: - Room state

    private func refresh(_ room: Room) {
        guard room === self.room else { return } // event from a room we already left

        switch room.connectionState {
        case .connected:
            state = .connected
        case .reconnecting:
            state = .reconnecting
        case .disconnected where state != .connecting: // join() handles failures while connecting
            let message = room.disconnectError?.localizedDescription
            self.room = nil
            tearDown()
            state = message.map { .failed($0) } ?? .idle
            return
        default:
            break
        }

        let speakers = Set(room.activeSpeakers.compactMap { $0.identity?.stringValue })
        let remotes = room.remoteParticipants.values.sorted { ($0.name ?? "") < ($1.name ?? "") }
        let all: [Participant] = [room.localParticipant] + remotes
        participants = all.compactMap { p in
            guard let id = p.identity?.stringValue else { return nil }
            let name = p.name.flatMap { $0.isEmpty ? nil : $0 } ?? id
            let isLocal = p is LocalParticipant
            let volume = isLocal ? 1 : Self.savedVolume(name)
            // Reapplied on every refresh so tracks subscribed later also get the saved volume.
            for track in p.audioTracks.compactMap({ $0.track as? RemoteAudioTrack }) {
                track.volume = volume
            }
            return ParticipantInfo(id: id,
                                   name: name,
                                   isSpeaking: speakers.contains(id),
                                   isMuted: !p.isMicrophoneEnabled(),
                                   isLocal: isLocal,
                                   volume: volume)
        }
    }

    #if DEBUG
    /// Manager with fixed data for SwiftUI previews; never connects.
    static func preview(state: State = .connected,
                        participants: [ParticipantInfo] = [],
                        isMicEnabled: Bool = true,
                        headphonesConnected: Bool = true,
                        micLevel: Float = 0.6) -> AudioRoomManager {
        let manager = AudioRoomManager()
        manager.state = state
        manager.participants = participants
        manager.isMicEnabled = isMicEnabled
        manager.headphonesConnected = headphonesConnected
        manager.micLevel = micLevel
        return manager
    }
    #endif
}

struct ParticipantInfo: Identifiable, Equatable {
    let id: String          // participant identity
    let name: String
    var isSpeaking: Bool
    var isMuted: Bool
    let isLocal: Bool
    var volume: Double = 1  // 1.0 = 100%, 0…2; always 1 for the local participant
}

/// Forwards the RoomDelegate events that change `state` or `participants`. Called on SDK threads.
private final class RoomObserver: NSObject, RoomDelegate, @unchecked Sendable {
    let onChange: @Sendable (Room) -> Void

    init(onChange: @escaping @Sendable (Room) -> Void) {
        self.onChange = onChange
    }

    func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldConnectionState: ConnectionState) { onChange(room) }
    func room(_ room: Room, participantDidConnect participant: RemoteParticipant) { onChange(room) }
    func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) { onChange(room) }
    func room(_ room: Room, didUpdateSpeakingParticipants participants: [Participant]) { onChange(room) }
    func room(_ room: Room, participant: Participant, didUpdateName name: String) { onChange(room) }
    func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) { onChange(room) }
    func room(_ room: Room, participant: LocalParticipant, didPublishTrack publication: LocalTrackPublication) { onChange(room) }
    func room(_ room: Room, participant: LocalParticipant, didUnpublishTrack publication: LocalTrackPublication) { onChange(room) }
    func room(_ room: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) { onChange(room) }
    func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) { onChange(room) }
    func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) { onChange(room) }
}
