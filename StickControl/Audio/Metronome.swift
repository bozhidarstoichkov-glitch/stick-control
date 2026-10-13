import AVFoundation
import QuartzCore
import UIKit

/// The audio device clocks a looping PCM score; UI frames never schedule clicks.
@MainActor
final class Metronome: NSObject {
    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private var displayLink: CADisplayLink?
    private var score: AVAudioPCMBuffer?
    private var cycleStrokes = 0
    private var patternCount = 0
    private var cycleFrames: Int64 = 0
    private var subdivision = 2
    var onFrame: ((Int, Int, TimeInterval) -> Void)?
    var onInterruption: (() -> Void)?
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!)
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in self?.onInterruption?() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue ||
                  raw == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue else { return }
            Task { @MainActor in self?.onInterruption?() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.onInterruption?()
                self.engine = AVAudioEngine(); self.player = AVAudioPlayerNode()
                self.engine.attach(self.player)
                self.engine.connect(self.player, to: self.engine.mainMixerNode,
                                    format: AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!)
            }
        })
    }

    func start(exercise: Exercise, bpm: Int, subdivision: Subdivision, audible: Bool) throws {
        stop()
        guard !exercise.strokes.isEmpty else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
        let rate = 48_000.0
        cycleStrokes = RhythmMath.cycleStrokeCount(patternCount: exercise.strokes.count, subdivision: subdivision)
        patternCount = exercise.strokes.count
        self.subdivision = subdivision.rawValue
        let interval = 60.0 / Double(min(250, max(30, bpm))) / Double(subdivision.rawValue)
        cycleFrames = Int64((Double(cycleStrokes) * interval * rate).rounded())
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(cycleFrames)),
              let samples = buffer.floatChannelData?[0] else { throw AudioError.bufferAllocation }
        buffer.frameLength = buffer.frameCapacity
        samples.initialize(repeating: 0, count: Int(cycleFrames))
        if audible {
            for tick in 0..<cycleStrokes {
                let stroke = exercise.strokes[tick % patternCount]
                // The click continues through rests so the drummer can keep counting.
                let downbeat = tick % (subdivision.rawValue * 4) == 0
                let accented = downbeat || stroke.accented
                let frequency = accented ? 1_760.0 : 1_100.0
                let gain = accented ? 0.65 : (tick % subdivision.rawValue == 0 ? 0.42 : 0.25)
                let start = Int((Double(tick) * Double(cycleFrames) / Double(cycleStrokes)).rounded())
                for frame in 0..<min(1_440, Int(cycleFrames) - start) {
                    let time = Double(frame) / rate
                    let attack = min(1, Double(frame) / 48)
                    samples[start + frame] = Float(sin(2 * .pi * frequency * time) * exp(-time * 180) * attack * gain)
                }
            }
        }
        score = buffer
        engine.prepare()
        do {
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            let link = CADisplayLink(target: self, selector: #selector(refresh))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            displayLink = link
        } catch { stop(); throw error }
    }

    @objc private func refresh() {
        guard let render = player.lastRenderTime, let time = player.playerTime(forNodeTime: render) else { return }
        // Rendered samples are ahead of what is heard by the output route's latency.
        let latency = player.outputPresentationLatency
        let heard = max(0, time.sampleTime - Int64(latency * time.sampleRate))
        let index = RhythmMath.strokeIndex(sample: heard, framesPerCycle: cycleFrames,
                                          cycleStrokes: cycleStrokes, patternCount: patternCount)
        let phase = heard % max(1, cycleFrames)
        let tick = min(cycleStrokes - 1, Int(Double(phase) * Double(cycleStrokes) / Double(cycleFrames)))
        onFrame?(index, (tick / subdivision) % 4, CACurrentMediaTime())
    }

    func stop(deactivate: Bool = false) {
        displayLink?.invalidate(); displayLink = nil
        player.stop(); engine.stop(); score = nil
        if deactivate { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }
    enum AudioError: LocalizedError {
        case bufferAllocation
        var errorDescription: String? { "The audio score could not be prepared. Try a shorter pattern." }
    }
}
