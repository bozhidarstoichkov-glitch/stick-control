# Stick Control

An offline native iPhone practice tool built with SwiftUI and AVAudioEngine. No accounts, backend, third-party app dependencies, or network calls.

## Open on an iPhone Simulator

On a Mac with Xcode 16 or newer and an installed iOS Simulator runtime:

1. Open `StickControl.xcodeproj`.
2. Select the **StickControl** scheme and an iPhone Simulator.
3. Press **⌘R**. Press **⌘U** to run the core tests through the iOS test target.

The deployment target is iOS 17. The project uses the SDK supplied by the selected Xcode installation. For a physical iPhone, select your signing team under Signing & Capabilities and choose a unique bundle identifier if needed.

For a command-line build and test on a Mac, run `./scripts/validate-ios.sh`.

## Practice

- Large R/L letters show the hand to use; `>` marks an accent and `–` marks a rest.
- Play highlights each stroke. The four small bars show the current beat in 4/4.
- Adjust tempo from 30–250 BPM with +/−, or tap the tempo. BPM always means quarter-note beats per minute.
- Choose quarters, eighths, triplets, or sixteenths. Each letter takes one subdivision.
- The first beat of each four-beat bar has a higher, louder click. Pattern accents also use an accented click. Clicks continue through rests; leave your hands silent on those strokes.
- Previous/next cycles through six original demonstration phrases and your saved custom patterns.
- **Custom pattern** accepts R, L, `-`, and `>` before a hand. Spaces and `|` are optional visual separators; bars do not change timing. Patterns can contain 1–64 strokes and are stored atomically in Application Support on the device.
- **Session** starts at the selected exercise and advances through the library. Configure exercise count, duration, starting tempo, per-exercise tempo increases, and optional increases within each exercise. Preview each step before starting. For +5 BPM every 2 minutes, choose an exercise duration longer than 2 minutes.

Pause freezes practice/session time. Resuming starts the phrase again on beat 1. Tempo/subdivision changes also restart the audio phrase. Session controls lock manual exercise/BPM changes; End returns to free practice. The display stays awake during playback. Leaving the foreground, audio interruptions, or headphone changes pause playback; it never resumes unexpectedly.

## Timing and architecture

`Core/` contains Codable exercise/stroke/subdivision models, a strict custom-pattern parser, an original exercise library, a monotonic-time session state machine, tap tempo, and audio/playhead math. It builds separately as the `StickControlCore` Swift package.

`Audio/Metronome.swift` builds a PCM score and lets `AVAudioPlayerNode` loop it on the audio device clock. No UI timer schedules sound. A cycle contains the least common multiple of the sticking length and the 4/4 subdivision count, keeping hands and bar accents aligned even for odd-length patterns. The entire cycle is rounded to a whole audio sample, preventing cumulative per-stroke rounding error. A CADisplayLink reads the player's sample position with output presentation-latency compensation for the visual playhead; it does not drive click timing.

`PracticeModel` owns playback, navigation, offline custom storage, and session transitions. `Views/` keeps practice, pattern editing, and session setup separate. Future libraries, routine persistence, and history can reuse the core models without changing audio timing.

## Validation in this cloud environment

This host is **Linux**, without Xcode, SwiftUI, AVFoundation, or an iPhone Simulator. A signature-verified Swift 6.2.3 Linux toolchain is installed under `/workspace/toolchains` for core validation. `./scripts/setup-linux.sh` reproduces/refreshes that setup with a pinned artifact checksum and runs the checks.

Verified here:

- The Swift package compiles and **11 XCTest tests pass**.
- All iOS Swift source files pass syntax parsing (this does not type-check Apple APIs).
- The Xcode project parses, source references exist, and the shared scheme is valid XML.

**The iOS application has not been compiled or launched here.** `validate-ios.sh` reports that missing prerequisite explicitly. Run its Xcode build/test and test the UI, speaker click, audio interruptions, and visual synchronization on a Mac/iPhone before calling this a usable release. Bluetooth adds route-specific latency; speaker/wired-headphone testing should establish the timing baseline. There is no background playback in this version.

Next useful features: saved custom routines, a count-in with configurable bar accents, and local practice history/daily goals.
