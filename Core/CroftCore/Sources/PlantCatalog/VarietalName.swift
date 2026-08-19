import Foundation

public enum VarietalName {
    public static func collisionKey(_ name: String) -> String {
        name.folding(options: .caseInsensitive, locale: nil)
    }

    public static func bare(_ name: String, cropNames: [String]) -> String {
        guard let separator = firstSeparatorOutsideParentheses(in: name) else { return name }
        let head = String(name[name.startIndex..<separator.lowerBound])
        let rest = String(name[separator.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return name }
        let (headWithoutQualifiers, qualifiers) = splitQualifiers(from: head)
        guard !headWithoutQualifiers.isEmpty, !rest.isEmpty else { return name }
        guard prefixNamesCrop(headWithoutQualifiers, cropNames: cropNames) else { return name }
        guard !qualifiers.isEmpty else { return rest }
        let suffix = qualifiers.map { "(\($0))" }.joined(separator: " ")
        return "\(rest) \(suffix)"
    }

    private static func firstSeparatorOutsideParentheses(in name: String) -> Range<String.Index>? {
        var depth = 0
        var index = name.startIndex
        while index < name.endIndex {
            let character = name[index]
            if character == "(" {
                depth += 1
            } else if character == ")" {
                depth = max(0, depth - 1)
            } else if depth == 0, isSpacedDash(at: index, in: name) {
                return name.index(before: index)..<name.index(index, offsetBy: 2)
            }
            index = name.index(after: index)
        }
        return nil
    }

    private static func isSpacedDash(at index: String.Index, in name: String) -> Bool {
        guard name[index] == "-", index > name.startIndex else { return false }
        guard name.index(after: index) < name.endIndex else { return false }
        return name[name.index(before: index)] == " " && name[name.index(after: index)] == " "
    }

    private static func splitQualifiers(from head: String) -> (String, [String]) {
        var bare = ""
        var qualifiers: [String] = []
        var current = ""
        var depth = 0
        for character in head {
            if character == "(" {
                depth += 1
                if depth == 1 { continue }
            } else if character == ")" {
                depth = max(0, depth - 1)
                if depth == 0 {
                    let qualifier = current.trimmingCharacters(in: .whitespaces)
                    if !qualifier.isEmpty {
                        qualifiers.append(qualifier)
                    }
                    current = ""
                    continue
                }
            }
            if depth > 0 {
                current.append(character)
            } else {
                bare.append(character)
            }
        }
        return (bare.trimmingCharacters(in: .whitespaces), qualifiers)
    }

    private static func prefixNamesCrop(_ head: String, cropNames: [String]) -> Bool {
        let headWords = words(of: head)
        guard !headWords.isEmpty else { return false }
        return cropNames.contains { crop in
            let cropWords = words(of: crop)
            guard !cropWords.isEmpty, cropWords.count <= headWords.count else { return false }
            return (0...(headWords.count - cropWords.count)).contains { offset in
                Array(headWords[offset..<(offset + cropWords.count)]) == cropWords
            }
        }
    }

    private static func words(of text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
