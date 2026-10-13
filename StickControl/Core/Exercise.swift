import Foundation

public enum Hand: String, Codable, Sendable { case right = "R", left = "L", rest = "-" }

public struct Stroke: Codable, Equatable, Sendable {
    public var hand: Hand
    public var accented: Bool
    public init(_ hand: Hand, accented: Bool = false) {
        self.hand = hand
        self.accented = hand != .rest && accented
    }
}

public enum Subdivision: Int, CaseIterable, Codable, Sendable {
    case quarter = 1, eighth = 2, triplet = 3, sixteenth = 4
    public var title: String {
        switch self {
        case .quarter: return "Quarter"
        case .eighth: return "Eighths"
        case .triplet: return "Triplets"
        case .sixteenth: return "Sixteenths"
        }
    }
}

public struct Exercise: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var strokes: [Stroke]
    public var subdivision: Subdivision
    public init(id: UUID = UUID(), name: String, strokes: [Stroke], subdivision: Subdivision = .eighth) {
        self.id = id; self.name = name; self.strokes = strokes; self.subdivision = subdivision
    }
    public var notation: String {
        strokes.map { ($0.accented ? ">" : "") + $0.hand.rawValue }.joined(separator: " ")
    }
}

public enum PatternError: Error, LocalizedError {
    case empty, invalidCharacter(String), danglingAccent, accentedRest, tooLong
    public var errorDescription: String? {
        switch self {
        case .empty: return "Enter at least one R or L stroke."
        case .invalidCharacter(let text): return "Unexpected character ‘\(text)’. Use R, L, -, and > for accents."
        case .danglingAccent: return "Place > directly before an R or L."
        case .accentedRest: return "A rest cannot have an accent."
        case .tooLong: return "Use up to 64 strokes per pattern."
        }
    }
}

public enum PatternParser {
    public static func parse(_ text: String) throws -> [Stroke] {
        var strokes: [Stroke] = []
        var accent = false
        for char in text.uppercased() {
            if char.isWhitespace || char == "|" { continue }
            if char == ">" {
                guard !accent else { throw PatternError.danglingAccent }
                accent = true; continue
            }
            guard let hand = Hand(rawValue: String(char)) else {
                throw PatternError.invalidCharacter(String(char))
            }
            if accent && hand == .rest { throw PatternError.accentedRest }
            strokes.append(Stroke(hand, accented: accent)); accent = false
            guard strokes.count <= 64 else { throw PatternError.tooLong }
        }
        guard !accent else { throw PatternError.danglingAccent }
        guard !strokes.isEmpty, strokes.contains(where: { $0.hand != .rest }) else { throw PatternError.empty }
        return strokes
    }
}

public enum ExerciseLibrary {
    // Original short practice phrases, not transcriptions of a drum book.
    public static let originals: [Exercise] = [
        make(1, "Alternating accents", ">R L R L R L >R L"),
        make(2, "Double shift", "R R >L L R >R L L"),
        make(3, "Three and two", ">R L L R L >R L R"),
        make(4, "Mirror phrase", "R >L R R L R >L L"),
        make(5, "Leave some space", ">R - L R L - >R L"),
        make(6, "Triplet turn", ">R L R L L R R >L R L R L", .triplet)
    ]
    private static func make(_ number: Int, _ name: String, _ text: String, _ subdivision: Subdivision = .eighth) -> Exercise {
        Exercise(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!,
                 name: name, strokes: try! PatternParser.parse(text), subdivision: subdivision)
    }
}
