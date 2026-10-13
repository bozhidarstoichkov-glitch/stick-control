import SwiftUI

struct SessionSetup: View {
    @ObservedObject var model: PracticeModel
    @Environment(\.dismiss) private var dismiss
    @State private var count = 3
    @State private var minutes = 2
    @State private var bpm = 80
    @State private var stepIncrease = 0
    @State private var progression = false
    @State private var amount = 5
    @State private var interval = 2
    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") {
                    Stepper("\(count) exercises", value: $count, in: 1...model.exercises.count)
                    Stepper("\(minutes) min per exercise", value: $minutes, in: 1...30)
                    Stepper("Starting tempo: \(bpm) BPM", value: $bpm, in: 30...250, step: 5)
                    Stepper("+\(stepIncrease) BPM per exercise", value: $stepIncrease, in: 0...20)
                    Text("Starts with \(model.exercise.name), then follows the library in order. Each exercise uses its saved subdivision.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Automatic tempo progression") {
                    Toggle("Increase within each exercise", isOn: $progression)
                    if progression {
                        Stepper("Increase: +\(amount) BPM", value: $amount, in: 1...30)
                        Stepper("Every \(interval) min", value: $interval, in: 1...10)
                        Text("The progression resets to the next exercise’s starting tempo. Tempo is capped at 250 BPM.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if interval >= minutes { Text("Choose an interval shorter than the exercise duration to hear an increase.").font(.footnote).foregroundStyle(.orange) }
                    }
                }
                Section("Preview") {
                    ForEach(0..<count, id: \.self) { offset in
                        let exercise = model.exercises[(model.selected + offset) % model.exercises.count]
                        HStack {
                            Text("\(offset + 1). \(exercise.name)")
                            Spacer()
                            Text("\(min(250, bpm + offset * stepIncrease)) BPM · \(minutes)m").foregroundStyle(.secondary)
                        }
                    }
                }
                Section { Text("Pausing stops the session clock. Locking the screen or leaving the app pauses playback. Use the app in the foreground while practicing.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Practice session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        model.startSession(count: count, minutes: minutes, startBPM: bpm, stepIncrease: stepIncrease,
                                           progression: progression ? TempoProgression(amount: amount, interval: Double(interval * 60)) : nil)
                        dismiss()
                    }
                }
            }
            .onAppear { bpm = model.bpm }
        }
    }
}
