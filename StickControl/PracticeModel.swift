import SwiftUI
import QuartzCore
import UIKit

@MainActor
final class PracticeModel: ObservableObject {
    @Published private(set) var exercises = ExerciseLibrary.originals
    @Published private(set) var selected = 0
    @Published var bpm = 80
    @Published var subdivision: Subdivision = .eighth
    @Published var audible = true
    @Published private(set) var playing = false
    @Published private(set) var strokeIndex = 0
    @Published private(set) var beat = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var session: SessionClock?
    @Published var error: String?
    @Published private(set) var completed = false
    private let audio = Metronome()
    private var tapTempo = TapTempo()
    private var lastFrame: TimeInterval?
    private let storageURL: URL
    var exercise: Exercise { session?.current?.exercise ?? exercises[selected] }
    var number: Int { (exercises.firstIndex(where: { $0.id == exercise.id }) ?? selected) + 1 }
    var nextName: String? { session?.next?.exercise.name }
    var remaining: TimeInterval? { session?.remaining }
    var sessionActive: Bool { session != nil }

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StickControl", isDirectory: true)
        storageURL = directory.appendingPathComponent("patterns.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: storageURL.path) {
                let custom = try JSONDecoder().decode([Exercise].self, from: Data(contentsOf: storageURL))
                exercises += custom.filter { !$0.strokes.isEmpty && $0.strokes.count <= 64 }
            }
        } catch { self.error = "Saved patterns could not be loaded: \(error.localizedDescription)" }
        audio.onFrame = { [weak self] stroke, beat, time in self?.frame(stroke: stroke, beat: beat, time: time) }
        audio.onInterruption = { [weak self] in self?.pause() }
    }

    func toggle() { playing ? pause() : play() }
    func play() {
        do {
            try audio.start(exercise: exercise, bpm: bpm, subdivision: subdivision, audible: audible)
            playing = true; lastFrame = CACurrentMediaTime(); completed = false
            UIApplication.shared.isIdleTimerDisabled = true
        } catch { pause(); self.error = "Audio could not start: \(error.localizedDescription)" }
    }
    func pause() {
        audio.stop(deactivate: true); playing = false; lastFrame = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }
    func restartAudio() { if playing { play() } }
    func changeTempo(_ change: Int) {
        guard !sessionActive else { return }
        bpm = min(250, max(30, bpm + change)); restartAudio()
    }
    func tap() {
        guard !sessionActive else { return }
        if let tempo = tapTempo.tap(at: CACurrentMediaTime()) { bpm = tempo; restartAudio() }
    }
    func navigate(_ offset: Int) {
        guard !sessionActive else { return }
        selected = (selected + offset + exercises.count) % exercises.count
        subdivision = exercise.subdivision; strokeIndex = 0; elapsed = 0; completed = false
        restartAudio()
    }
    func addPattern(name: String, text: String, subdivision: Subdivision) throws {
        let strokes = try PatternParser.parse(text)
        let custom = Exercise(name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My pattern" : name,
                              strokes: strokes, subdivision: subdivision)
        let updated = exercises + [custom]
        let data = try JSONEncoder().encode(Array(updated.dropFirst(ExerciseLibrary.originals.count)))
        try data.write(to: storageURL, options: .atomic)
        exercises = updated; selected = exercises.count - 1
        self.subdivision = subdivision; strokeIndex = 0; elapsed = 0
        restartAudio()
    }
    func startSession(count: Int, minutes: Int, startBPM: Int, stepIncrease: Int, progression: TempoProgression?) {
        pause()
        let steps = (0..<count).map { offset in
            SessionStep(exercise: exercises[(selected + offset) % exercises.count],
                        bpm: startBPM + offset * stepIncrease, duration: Double(minutes * 60))
        }
        session = SessionClock(steps: steps, progression: progression)
        elapsed = 0; strokeIndex = 0; completed = false
        bpm = session!.bpm; subdivision = exercise.subdivision; play()
    }
    func endSession() {
        pause(); session = nil; completed = false; elapsed = 0; strokeIndex = 0
        subdivision = exercises[selected].subdivision
    }
    private func frame(stroke: Int, beat: Int, time: TimeInterval) {
        guard playing else { return }
        let delta = max(0, time - (lastFrame ?? time)); lastFrame = time
        elapsed += delta
        if var clock = session {
            let oldIndex = clock.index, oldBPM = clock.bpm
            clock.advance(by: delta); session = clock
            if clock.finished {
                pause()
                if let last = clock.steps.last, let index = exercises.firstIndex(where: { $0.id == last.exercise.id }) {
                    selected = index; bpm = clock.bpm; subdivision = last.exercise.subdivision
                }
                session = nil; strokeIndex = 0; completed = true; return
            }
            if clock.index != oldIndex || clock.bpm != oldBPM {
                bpm = clock.bpm; subdivision = exercise.subdivision; strokeIndex = 0; restartAudio(); return
            }
        }
        strokeIndex = stroke; self.beat = beat
    }
}
