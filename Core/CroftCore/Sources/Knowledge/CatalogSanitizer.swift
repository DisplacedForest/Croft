import Foundation

public enum SanitizerError: Error, Equatable {
    case unreadableCatalog(String)
    case unexpectedShape(String)
}

public enum CatalogSanitizer {
    public static let strippedFields = [
        "price", "flavor_profile", "vendor", "url",
        "image_url", "image_file", "image_shared",
    ]

    public static func sanitize(rawCatalog data: Data) throws -> Data {
        let parsed = try JSONSerialization.jsonObject(with: data)
        guard var root = parsed as? [String: Any] else {
            throw SanitizerError.unexpectedShape("top level is not an object")
        }
        guard let rows = root["cultivars"] as? [[String: Any]] else {
            throw SanitizerError.unexpectedShape("cultivars is not an array of objects")
        }
        let cleaned = rows.map { row in
            row.filter { !strippedFields.contains($0.key) }
        }
        if var meta = root["meta"] as? [String: Any] {
            if let coverage = meta["coverage_pct"] as? [String: Any] {
                meta["coverage_pct"] = coverage.filter { !strippedFields.contains($0.key) }
            }
            root["meta"] = meta
        }
        let sorted = cleaned.sorted { left, right in
            let leftKey = sortKey(of: left)
            let rightKey = sortKey(of: right)
            return leftKey == rightKey
                ? stableText(of: left) < stableText(of: right)
                : leftKey < rightKey
        }
        root["cultivars"] = sorted
        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        )
    }

    private static func sortKey(of row: [String: Any]) -> String {
        let crop = row["crop"] as? String ?? ""
        let cultivar = row["cultivar"] as? String ?? ""
        let origin = row["data_origin"] as? String ?? ""
        return "\(crop)|\(cultivar)|\(origin)"
    }

    private static func stableText(of row: [String: Any]) -> String {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: row, options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return text
    }
}
