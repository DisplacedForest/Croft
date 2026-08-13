public enum Slug {
    public static func make(_ text: String) -> String {
        var out = ""
        var pendingHyphen = false
        for scalar in text.lowercased().unicodeScalars {
            if scalar.properties.isAlphabetic || ("0"..."9").contains(String(scalar)) {
                if pendingHyphen && !out.isEmpty {
                    out.append("-")
                }
                pendingHyphen = false
                out.unicodeScalars.append(scalar)
            } else {
                pendingHyphen = true
            }
        }
        return out
    }
}

public enum KnowledgeID {
    public static func family(_ name: String) -> String { "family:\(Slug.make(name))" }
    public static func genus(_ name: String) -> String { "genus:\(Slug.make(name))" }
    public static func species(_ latinName: String) -> String { "species:\(Slug.make(latinName))" }

    public static func cultivar(speciesID: String, name: String) -> String {
        let base = speciesID.replacingOccurrences(of: "species:", with: "")
        return "cultivar:\(base)/\(Slug.make(name))"
    }

    public static func pest(_ sourceID: String) -> String { "pest:\(Slug.make(sourceID))" }
    public static func disease(_ sourceID: String) -> String { "disease:\(Slug.make(sourceID))" }
    public static func pathogen(_ name: String) -> String { "pathogen:\(Slug.make(name))" }

    public static func edge(from source: String, type: String, to target: String) -> String {
        "edge:\(source)|\(type)|\(target)"
    }
}
