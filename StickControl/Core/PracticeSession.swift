import Foundation

public struct SessionStep: Equatable, Sendable {
    public var exercise: Exercise
    public var bpm: Int
    public var duration: TimeInterval
    public init(exercise: Exercise, bpm: Int, duration: TimeInterval) {
        self.exercise = exercise
        self.bpm = min(250, max(30, bpm))
        self.duration = max(1, duration)
    }
}

public struct TempoProgression: Equatable, Sendable {
    public var amount: Int
    public var interval: TimeInterval
    public init(amount: Int, interval: TimeInterval) {
        self.amount = min(30, max(1, amount)); self.interval = max(1, interval)
    }
}

/// Pure session clock. Advance with elapsed monotonic time only while playing.
public struct SessionClock: Sendable {
    public let steps: [SessionStep]
    public let progression: TempoProgression?
    public private(set) var index = 0
    public private(set) var elapsed: TimeInterval = 0
    public private(set) var finished = false
    public init(steps: [SessionStep], progression: TempoProgression? = nil) {
        self.steps = steps; self.progression = progression; finished = steps.isEmpty
    }
    public var current: SessionStep? { finished ? nil : steps[index] }
    public var next: SessionStep? { index + 1 < steps.count ? steps[index + 1] : nil }
    public var remaining: TimeInterval { max(0, (current?.duration ?? 0) - elapsed) }
    public var bpm: Int {
        guard let current else { return steps.last?.bpm ?? 80 }
        let increases = progression.map { Int(elapsed / $0.interval) * $0.amount } ?? 0
        return min(250, current.bpm + increases)
    }
    public mutating func advance(by seconds: TimeInterval) {
        guard !finished, seconds.isFinite, seconds > 0 else { return }
        elapsed += seconds
        while !finished && elapsed >= steps[index].duration {
            elapsed -= steps[index].duration
            if index + 1 < steps.count { index += 1 }
            else { finished = true; elapsed = 0 }
        }
    }
}

public struct TapTempo: Sendable {
    private var taps: [TimeInterval] = []
    public init() {}
    public mutating func tap(at time: TimeInterval) -> Int? {
        if let previous = taps.last, time - previous > 2 || time <= previous { taps.removeAll() }
        taps.append(time)
        if taps.count > 5 { taps.removeFirst() }
        guard taps.count >= 2 else { return nil }
        let interval = (taps.last! - taps.first!) / Double(taps.count - 1)
        return min(250, max(30, Int((60 / interval).rounded())))
    }
}

public enum RhythmMath {
    public static func cycleStrokeCount(patternCount: Int, subdivision: Subdivision) -> Int {
        guard patternCount > 0 else { return 0 }
        let beats = subdivision.rawValue * 4
        var a = patternCount, b = beats
        while b != 0 { let r = a % b; a = b; b = r }
        return patternCount / a * beats
    }
    public static func strokeIndex(sample: Int64, framesPerCycle: Int64, cycleStrokes: Int, patternCount: Int) -> Int {
        guard sample >= 0, framesPerCycle > 0, cycleStrokes > 0, patternCount > 0 else { return 0 }
        let phase = sample % framesPerCycle
        return min(cycleStrokes - 1, Int(Double(phase) * Double(cycleStrokes) / Double(framesPerCycle))) % patternCount
    }
}
