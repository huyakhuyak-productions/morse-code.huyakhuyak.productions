/// One element of a Morse character.
public enum Element: Sendable, Hashable, Codable {
    case dot
    case dash
}

/// The Morse code of one character.
public struct Code: Sendable, Hashable, Codable {
    public let elements: [Element]

    public init(elements: [Element]) {
        self.elements = elements
    }

    /// Human-readable form: em dash for a dash, middle dot for a dot, single spaces between.
    public var display: String {
        elements.map { $0 == .dot ? "·" : "—" }.joined(separator: " ")
    }
}

/// The international Morse table for the 36 characters this app teaches.
public enum Morse {
    /// Fixed home-grid order: A–Z then 0–9.
    public static let gridOrder: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    /// Koch teaching order, filtered to letters and digits.
    public static let kochOrder: [Character] = Array("KMRSUAPTLOWINJEF0YVG5Q9ZH38B7C1D6X24")

    public static func code(for character: Character) -> Code? {
        table[character]
    }

    private static let table: [Character: Code] = {
        let raw: [Character: String] = [
            "A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".", "F": "..-.",
            "G": "--.", "H": "....", "I": "..", "J": ".---", "K": "-.-", "L": ".-..",
            "M": "--", "N": "-.", "O": "---", "P": ".--.", "Q": "--.-", "R": ".-.",
            "S": "...", "T": "-", "U": "..-", "V": "...-", "W": ".--", "X": "-..-",
            "Y": "-.--", "Z": "--..",
            "0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
            "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.",
        ]
        return raw.mapValues { Code(elements: $0.map { $0 == "." ? .dot : .dash }) }
    }()
}
