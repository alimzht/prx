import Foundation

struct SavedRoom: Codable, Identifiable, Equatable {
    let code: String
    var name: String      // пустое — показываем «Комната»
    var lastUsed: Date
    var id: String { code }

    var displayName: String { name.isEmpty ? "Комната" : name }
}

/// Сохранённые комнаты на этом телефоне. Сервера нет, поэтому название живёт локально и передаётся друзьям через ссылку.
@MainActor
final class RoomStore: ObservableObject {
    @Published private(set) var rooms: [SavedRoom] = []

    private static let key = "savedRooms"
    private static let limit = 10
    static let maxNameLength = 30

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([SavedRoom].self, from: data) {
            rooms = saved
        }
    }

    func displayName(for code: String) -> String {
        rooms.first { $0.code == code }?.displayName ?? "Комната"
    }

    /// Добавляет комнату или поднимает её наверх. Название меняется, только если передано.
    func touch(code: String, name: String? = nil) {
        var room = rooms.first { $0.code == code } ?? SavedRoom(code: code, name: "", lastUsed: Date())
        room.lastUsed = Date()
        if let name { room.name = Self.clean(name) }
        rooms.removeAll { $0.code == code }
        rooms.insert(room, at: 0)
        rooms = Array(rooms.prefix(Self.limit))
        save()
    }

    func rename(code: String, to name: String) {
        guard let index = rooms.firstIndex(where: { $0.code == code }) else {
            touch(code: code, name: name)
            return
        }
        rooms[index].name = Self.clean(name)
        save()
    }

    func remove(code: String) {
        rooms.removeAll { $0.code == code }
        save()
    }

    /// Ссылка-приглашение с названием, чтобы у друга комната сохранилась так же.
    func inviteURL(for code: String) -> String {
        var components = URLComponents()
        components.scheme = "prx"
        components.host = "join"
        components.path = "/" + code
        let name = rooms.first { $0.code == code }?.name ?? ""
        if !name.isEmpty { components.queryItems = [URLQueryItem(name: "name", value: name)] }
        return components.url?.absoluteString ?? "prx://join/\(code)"
    }

    static func clean(_ name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNameLength))
    }

    private func save() {
        if let data = try? JSONEncoder().encode(rooms) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    #if DEBUG
    static func preview() -> RoomStore {
        let store = RoomStore()
        store.rooms = [
            SavedRoom(code: "K7Q2XP", name: "Сквад", lastUsed: Date()),
            SavedRoom(code: "M4RT9Z", name: "", lastUsed: Date().addingTimeInterval(-86_400)),
        ]
        return store
    }
    #endif
}
