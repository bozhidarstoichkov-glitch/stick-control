import SwiftUI

struct PatternEditor: View {
    @ObservedObject var model: PracticeModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var pattern = ""
    @State private var subdivision: Subdivision = .eighth
    @State private var error: String?
    private var preview: [Stroke]? { try? PatternParser.parse(pattern) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("My pattern", text: $name).textInputAutocapitalization(.words) }
                Section("Sticking") {
                    TextField("R L >R R | L - L R", text: $pattern, axis: .vertical)
                        .font(.system(.title2, design: .monospaced)).autocorrectionDisabled().textInputAutocapitalization(.characters)
                    Text("R = right · L = left · - = rest\n> accents the next stroke. Spaces and | are optional. Up to 64 strokes.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let preview {
                        Text("\(preview.count) strokes · \(preview.filter(\.accented).count) accents").foregroundStyle(.green)
                    } else if !pattern.isEmpty {
                        Text(validationMessage).foregroundStyle(.orange)
                    }
                }
                Section("Subdivision") {
                    Picker("Strokes per beat", selection: $subdivision) {
                        ForEach(Subdivision.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Custom pattern")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try model.addPattern(name: name, text: pattern, subdivision: subdivision); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.disabled(preview == nil)
                }
            }
        }
    }
    private var validationMessage: String {
        do { _ = try PatternParser.parse(pattern); return "" }
        catch { return error.localizedDescription }
    }
}
