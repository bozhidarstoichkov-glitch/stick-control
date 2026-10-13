import SwiftUI

private let mint = Color(red: 0.55, green: 0.98, blue: 0.76)

struct PracticeView: View {
    @ObservedObject var model: PracticeModel
    @State private var editor = false
    @State private var sessionSetup = false
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                header
                if geometry.size.width > geometry.size.height {
                    HStack(spacing: 24) {
                        pattern
                        ScrollView { controls }.frame(width: 280)
                    }
                } else {
                    pattern
                    controls
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.045, green: 0.055, blue: 0.065))
        }
        .tint(mint)
        .sheet(isPresented: $editor) { PatternEditor(model: model) }
        .sheet(isPresented: $sessionSetup) { SessionSetup(model: model) }
        .alert("Something needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("STICK CONTROL").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(3).foregroundStyle(mint)
                Text("\(String(format: "%02d", model.number))  /  \(model.exercise.name)")
                    .font(.headline).lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(time(model.remaining ?? model.elapsed)).font(.system(size: 30, weight: .semibold, design: .monospaced)).monospacedDigit()
                Text(model.sessionActive ? "REMAINING" : "PRACTICE TIME").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            }.accessibilityElement(children: .combine)
        }
    }
    private var pattern: some View {
        GeometryReader { geometry in
            let columns = geometry.size.width > 600 ? 8 : 4
            let fontSize = min(88.0, (geometry.size.width - Double(columns - 1) * 8) / Double(columns) * 0.8)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 14) {
                        ForEach(Array(model.exercise.strokes.enumerated()), id: \.offset) { index, stroke in
                            let current = model.playing && model.strokeIndex == index
                            VStack(spacing: 0) {
                                Text(stroke.accented ? ">" : " ")
                                    .font(.system(size: 22, weight: .heavy)).foregroundStyle(current ? .black : mint)
                                Text(stroke.hand == .rest ? "–" : stroke.hand.rawValue)
                                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(current ? .black : (stroke.hand == .rest ? .gray : .white))
                                Text(index % model.subdivision.rawValue == 0 ? "\((index / model.subdivision.rawValue) % 4 + 1)" : "·")
                                    .font(.caption.bold()).foregroundStyle(current ? .black.opacity(0.6) : .secondary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(current ? mint : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
                            .id(index)
                            .accessibilityLabel("Stroke \(index + 1), \(stroke.hand == .right ? "right" : stroke.hand == .left ? "left" : "rest")\(stroke.accented ? ", accented" : "")")
                        }
                    }.padding(.vertical, 8)
                }
                .onChange(of: model.strokeIndex) { _, value in proxy.scrollTo(value, anchor: .center) }
                .onChange(of: model.exercise.id) { _, _ in proxy.scrollTo(0, anchor: .top) }
            }
        }
        .frame(minHeight: 140)
    }
    private var controls: some View {
        VStack(spacing: 12) {
            if model.sessionActive || model.completed {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.completed ? "SESSION COMPLETE" : "SESSION · STEP \((model.session?.index ?? 0) + 1)")
                            .font(.caption.bold()).foregroundStyle(mint)
                        Text(model.nextName.map { "Next: \($0)" } ?? (model.completed ? "Nice work. Take a breath." : "Final exercise"))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    Button(model.completed ? "Dismiss" : "End", action: model.endSession).font(.subheadline)
                }
            }
            HStack(spacing: 16) {
                control("minus", label: "Decrease tempo") { model.changeTempo(-1) }.disabled(model.sessionActive || model.bpm == 30)
                VStack(spacing: 0) {
                    Text("\(model.bpm)").font(.system(size: 68, weight: .semibold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.7)
                    Text("BPM").font(.caption.bold()).tracking(2).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).accessibilityLabel("\(model.bpm) beats per minute")
                control("plus", label: "Increase tempo") { model.changeTempo(1) }.disabled(model.sessionActive || model.bpm == 250)
            }
            HStack(spacing: 10) {
                Button("Tap tempo", action: model.tap).buttonStyle(.bordered).disabled(model.sessionActive)
                Picker("Subdivision", selection: $model.subdivision) {
                    ForEach(Subdivision.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.menu).disabled(model.sessionActive)
                    .onChange(of: model.subdivision) { _, _ in model.restartAudio() }
                Spacer(minLength: 0)
                Button {
                    model.audible.toggle(); model.restartAudio()
                } label: { Image(systemName: model.audible ? "speaker.wave.2.fill" : "speaker.slash.fill").frame(width: 44, height: 44) }
                .accessibilityLabel(model.audible ? "Mute metronome" : "Enable metronome")
            }.font(.subheadline)
            HStack(spacing: 8) {
                ForEach(0..<4) { beat in
                    Capsule().fill(model.playing && model.beat == beat ? mint : Color.white.opacity(0.12)).frame(height: 5)
                }
            }.accessibilityHidden(true)
            HStack(spacing: 16) {
                control("backward.end.fill", label: "Previous exercise") { model.navigate(-1) }.disabled(model.sessionActive)
                Button(action: model.toggle) {
                    Label(model.playing ? "Pause" : "Play", systemImage: model.playing ? "pause.fill" : "play.fill")
                        .font(.title2.bold()).frame(maxWidth: .infinity).frame(height: 64)
                        .foregroundStyle(.black).background(mint, in: RoundedRectangle(cornerRadius: 18))
                }
                control("forward.end.fill", label: "Next exercise") { model.navigate(1) }.disabled(model.sessionActive)
            }
            HStack {
                Button { model.pause(); editor = true } label: { Label("Custom pattern", systemImage: "square.and.pencil") }
                Spacer()
                Button { model.pause(); sessionSetup = true } label: { Label("Session", systemImage: "list.bullet.rectangle") }
            }.font(.subheadline).disabled(model.sessionActive).padding(.top, 4)
        }
    }
    private func control(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.title3.bold()).frame(width: 48, height: 52).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14)) }
            .accessibilityLabel(label)
    }
    private func time(_ seconds: TimeInterval) -> String {
        let value = Int(model.sessionActive ? seconds.rounded(.up) : seconds.rounded(.down))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
