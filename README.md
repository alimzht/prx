# prx

Background voice chat for mobile gaming. prx runs in the background while you play and
carries a group voice chat (up to 10 people per room) without lowering the game's sound
and without dropping your AirPods into low-quality call mode (HFP).

Your voice goes through the iPhone's built-in microphone. Game audio and your friends'
voices play through your headphones over A2DP at full quality. Headphones are required.

## How it works

Discord and Telegram use the `voiceChat` audio-session mode, which ducks other apps and
switches Bluetooth headphones to HFP so their mic can be used. prx instead uses
`.playAndRecord` with mode `.default` and the options `.mixWithOthers` and
`.allowBluetoothA2DP` (never `.allowBluetooth`, which enables HFP), turns off Apple's
voice processing, and pins the input to the built-in mic. iOS can only record from a
Bluetooth headset over HFP, so the mic stays on the phone while playback stays on A2DP.
No CallKit, so the system never treats the session as a phone call.

## Setup (LiveKit Cloud)

1. Create a free project at [cloud.livekit.io](https://cloud.livekit.io).
2. Open the project's **Settings** and turn on **Development token server**.
3. Copy the **Token server ID** shown under the toggle.
4. In this GitHub repo: Settings → Secrets and variables → Actions → New repository
   secret, name `LK_SANDBOX_ID`, value = the token server ID.

The development token server hands out tokens to anyone who has the ID. Fine for
friends, not for production.

## Build

No Mac needed. GitHub Actions builds an unsigned `prx.ipa` on every push to `main`
(or run it manually: Actions → iOS → Run workflow). Open the finished run and download
the `prx-ipa` artifact (a zip containing `prx.ipa`).

## Install from Windows (Sideloadly)

1. Install iTunes and iCloud from Apple's website (not the Microsoft Store), then
   [Sideloadly](https://sideloadly.io).
2. Connect the iPhone by USB and trust the computer.
3. Drag `prx.ipa` into Sideloadly, enter a free Apple ID, and click Start.
4. On the iPhone: Settings → Privacy & Security → **Developer Mode** → on (restart).
   Then Settings → General → VPN & Device Management → trust your Apple ID.

Apps signed with a free Apple ID expire after **7 days**. Re-sign by running Sideloadly
again with the same IPA.

## Testing tip

You need a second participant. Join the same room from a browser with
[LiveKit Meet](https://meet.livekit.io): with the [LiveKit CLI](https://github.com/livekit/livekit-cli)
linked to your project (`lk cloud auth`), run

```shell
lk token create --join --room <code> --identity web --open meet
```

where `<code>` is the room code you typed in prx.
