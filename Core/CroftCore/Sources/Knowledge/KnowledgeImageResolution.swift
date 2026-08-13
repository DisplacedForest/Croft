import Foundation
import Graph

extension KnowledgeMapper {
    struct ImageResolver {
        private let owners: [String: String]
        private let speciesByCrop: [String: String]
        private let hostPairs: Set<String>

        init(taxonomy: Taxonomy, mapped: MappedKnowledge) {
            var owners: [String: String] = [:]
            var cropBySpecies: [String: String] = [:]
            for (crop, speciesID) in taxonomy.speciesByCrop {
                owners["species:\(crop)"] = speciesID
                cropBySpecies[speciesID] = crop
            }
            for cultivar in mapped.cultivars {
                guard let crop = cropBySpecies[cultivar.speciesID.rawValue] else { continue }
                owners["cultivar:\(crop)/\(Self.leaf(of: cultivar.id.rawValue))"] =
                    cultivar.id.rawValue
            }
            for pest in mapped.pests {
                owners["pest:pest/\(Self.leaf(of: pest.id.rawValue))"] = pest.id.rawValue
            }
            for disease in mapped.diseases {
                owners["disease:disease/\(Self.leaf(of: disease.id.rawValue))"] =
                    disease.id.rawValue
            }
            var hostPairs: Set<String> = []
            for edge in mapped.edges where edge.type == .hostOf || edge.type == .susceptibleTo {
                hostPairs.insert("\(edge.target.id)|\(edge.source.id)")
            }
            self.owners = owners
            self.speciesByCrop = taxonomy.speciesByCrop
            self.hostPairs = hostPairs
        }

        private static func leaf(of id: String) -> String {
            let afterNamespace = id.split(separator: ":").last.map(String.init) ?? id
            return afterNamespace.split(separator: "/").last.map(String.init) ?? afterNamespace
        }

        func ownerID(for image: PlantImageInput) -> String? {
            owners["\(image.ownerKind.rawValue):\(image.slug)"]
        }

        func relatedID(for image: PlantImageInput, ownerID: String) throws -> String? {
            let raw = image.relatedSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !raw.isEmpty else { return nil }
            guard let speciesID = speciesByCrop[raw] else {
                throw ImportError.unknownImageRelation(slug: image.slug, relatedSlug: raw)
            }
            guard hostPairs.contains("\(ownerID)|\(speciesID)") else {
                throw ImportError.unrelatedImageHost(slug: image.slug, relatedSlug: raw)
            }
            return speciesID
        }
    }

    func mapImages(
        _ taxonomy: Taxonomy,
        into mapped: inout MappedKnowledge
    ) throws {
        guard let manifest = inputs.images else { return }
        mapped.inputVersions[manifest.meta.name] = manifest.meta.version
        if let provenance = manifest.meta.provenance {
            mapped.inputProvenance[manifest.meta.name] = provenance
        }
        let resolver = ImageResolver(taxonomy: taxonomy, mapped: mapped)
        for image in manifest.images {
            mapped.images.append(try mapImage(image, with: resolver))
        }
        mapped.images.sort { $0.sortKey < $1.sortKey }
        var seen: Set<String> = []
        for image in mapped.images where !seen.insert(image.primaryKey).inserted {
            throw ImportError.duplicateRecord("image \(image.primaryKey)")
        }
    }

    private func mapImage(
        _ image: PlantImageInput,
        with resolver: ImageResolver
    ) throws -> MappedImage {
        guard let file = image.file, let sha256 = image.sha256, let license = image.license,
            let sourcePage = image.sourcePageURL, let sourceFile = image.sourceFileURL
        else {
            throw ImportError.invalidImageField(slug: image.slug, field: "file")
        }
        guard let ownerID = resolver.ownerID(for: image) else {
            throw ImportError.unknownImageOwner(file: file, slug: image.slug)
        }
        return MappedImage(
            ownerKind: image.ownerKind.rawValue,
            ownerID: ownerID,
            relatedID: try resolver.relatedID(for: image, ownerID: ownerID),
            kind: image.kind,
            file: file,
            sha256: sha256.lowercased(),
            license: license,
            licenseURL: image.licenseURL,
            artist: image.artist,
            sourcePageURL: sourcePage,
            sourceFileURL: sourceFile
        )
    }
}
