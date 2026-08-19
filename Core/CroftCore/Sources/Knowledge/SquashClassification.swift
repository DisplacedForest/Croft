import Foundation

enum SquashClassification: Equatable {
    case crop(String)
    case gourd
    case unknown

    private static let gourdMarkers = ["gourd", "luffa", "cucuzzi"]
    private static let summerMarkers = [
        "zucchini", "crookneck", "straightneck", "scallop", "cocozelle", "pattypan",
        "black beauty", "lemon squash",
    ]
    private static let winterMarkers = [
        "butternut", "butterneck", "butterbush", "acorn", "delicata", "hubbard",
        "buttercup", "spaghetti", "kabocha", "honeynut", "sweet meat", "sweet dumpling",
        "candy roaster", "futsu", "musquee", "golden pippin",
    ]

    static func classify(cultivarNamed name: String) -> SquashClassification {
        let lowered = name.lowercased()
        if gourdMarkers.contains(where: lowered.contains) {
            return .gourd
        }
        if lowered.contains("(summer)") {
            return .crop("summer-squash")
        }
        if lowered.contains("(winter)") || lowered.contains("cushaw") {
            return .crop("winter-squash")
        }
        if lowered.hasPrefix("pumpkin") {
            return .crop("pumpkin")
        }
        if summerMarkers.contains(where: lowered.contains) {
            return .crop("summer-squash")
        }
        if winterMarkers.contains(where: lowered.contains) {
            return .crop("winter-squash")
        }
        return .unknown
    }
}
