import XCTest
#if canImport(StickControlCore)
@testable import StickControlCore
#else
@testable import StickControl
#endif

final class CoreTests: XCTestCase {
    func testParserHandlesAccentsRestsAndBars() throws {
        let strokes = try PatternParser.parse(">r l | - R")
        XCTAssertEqual(strokes, [Stroke(.right, accented: true), Stroke(.left), Stroke(.rest), Stroke(.right)])
    }
    func testParserRejectsInvalidPatterns() {
        for text in ["", "---", "R X L", "R >", ">-", ">>R", String(repeating: "R", count: 65)] {
            XCTAssertThrowsError(try PatternParser.parse(text), text)
        }
    }
    func testOriginalLibraryHasStableUniqueIDsAndValidPatterns() throws {
        let library = ExerciseLibrary.originals
        XCTAssertEqual(Set(library.map(\.id)).count, library.count)
        for exercise in library { XCTAssertEqual(try PatternParser.parse(exercise.notation), exercise.strokes) }
    }
    func testExerciseRoundTripsOffline() throws {
        let exercise = Exercise(name: "Custom", strokes: try PatternParser.parse(">R L - L"), subdivision: .triplet)
        XCTAssertEqual(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(exercise)), exercise)
    }
    func testSessionTransitionsAndCarriesElapsedTime() {
        let exercises = ExerciseLibrary.originals
        var clock = SessionClock(steps: [SessionStep(exercise: exercises[0], bpm: 80, duration: 120),
                                        SessionStep(exercise: exercises[1], bpm: 85, duration: 120)])
        clock.advance(by: 125)
        XCTAssertEqual(clock.index, 1)
        XCTAssertEqual(clock.remaining, 115)
        XCTAssertEqual(clock.bpm, 85)
        clock.advance(by: 115)
        XCTAssertTrue(clock.finished)
        XCTAssertNil(clock.current)
        XCTAssertEqual(clock.remaining, 0)
    }
    func testTempoProgressionResetsAtNextStepAndCaps() {
        let exercise = ExerciseLibrary.originals[0]
        var clock = SessionClock(steps: [SessionStep(exercise: exercise, bpm: 245, duration: 300),
                                        SessionStep(exercise: exercise, bpm: 80, duration: 300)],
                                 progression: TempoProgression(amount: 5, interval: 120))
        clock.advance(by: 240)
        XCTAssertEqual(clock.bpm, 250)
        clock.advance(by: 60)
        XCTAssertEqual(clock.bpm, 80)
    }
    func testEmptySessionAndLargeAdvance() {
        XCTAssertTrue(SessionClock(steps: []).finished)
        let exercise = ExerciseLibrary.originals[0]
        var clock = SessionClock(steps: (0..<3).map { _ in SessionStep(exercise: exercise, bpm: 80, duration: 10) })
        clock.advance(by: 100)
        XCTAssertTrue(clock.finished)
    }
    func testClockIgnoresInvalidTime() {
        var clock = SessionClock(steps: [SessionStep(exercise: ExerciseLibrary.originals[0], bpm: 80, duration: 120)])
        clock.advance(by: -.infinity); clock.advance(by: .nan); clock.advance(by: -5)
        XCTAssertEqual(clock.elapsed, 0)
    }
    func testTapTempoAndLongGapReset() {
        var tap = TapTempo()
        XCTAssertNil(tap.tap(at: 1))
        XCTAssertEqual(tap.tap(at: 1.5), 120)
        XCTAssertEqual(tap.tap(at: 2), 120)
        XCTAssertNil(tap.tap(at: 5))
        XCTAssertEqual(tap.tap(at: 6), 60)
    }
    func testAudioCycleKeepsPatternAndFourBeatBarAligned() {
        XCTAssertEqual(RhythmMath.cycleStrokeCount(patternCount: 5, subdivision: .sixteenth), 80)
        XCTAssertEqual(RhythmMath.cycleStrokeCount(patternCount: 8, subdivision: .eighth), 8)
        XCTAssertEqual(RhythmMath.cycleStrokeCount(patternCount: 12, subdivision: .triplet), 12)
    }
    func testPlayheadWrapsAtAudioCycleBoundary() {
        XCTAssertEqual(RhythmMath.strokeIndex(sample: 0, framesPerCycle: 8000, cycleStrokes: 8, patternCount: 8), 0)
        XCTAssertEqual(RhythmMath.strokeIndex(sample: 3999, framesPerCycle: 8000, cycleStrokes: 8, patternCount: 8), 3)
        XCTAssertEqual(RhythmMath.strokeIndex(sample: 4000, framesPerCycle: 8000, cycleStrokes: 8, patternCount: 8), 4)
        XCTAssertEqual(RhythmMath.strokeIndex(sample: 8000, framesPerCycle: 8000, cycleStrokes: 8, patternCount: 8), 0)
        XCTAssertEqual(RhythmMath.strokeIndex(sample: 7000, framesPerCycle: 8000, cycleStrokes: 8, patternCount: 3), 1)
    }
}
