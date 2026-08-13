import Foundation

struct MappedImage {
    let ownerKind: String
    let ownerID: String
    let relatedID: String?
    let kind: String
    let file: String
    let sha256: String
    let license: String
    let licenseURL: String?
    let artist: String?
    let sourcePageURL: String
    let sourceFileURL: String

    var sortKey: String {
        "\(ownerKind)|\(ownerID)|\(kind)|\(file)"
    }
}

extension KnowledgeImporter {
    var imageManifestURL: URL {
        inputDirectory.appendingPathComponent(Self.plantImagesFile)
    }

    var imageManifestExists: Bool {
        FileManager.default.fileExists(atPath: imageManifestURL.path)
    }

    public static let allowedImageLicenses: Set<String> = [
        "Public domain", "CC0", "CC0 1.0", "CC BY 1.0", "CC BY 2.0",
        "CC BY 2.5", "CC BY 3.0", "CC BY 3.0 us", "CC BY 4.0",
    ]

    func validateImageRecords(_ manifest: PlantImagesFile) throws {
        for image in manifest.images {
            let required: [(String, String?)] = [
                ("file", image.file),
                ("sha256", image.sha256),
                ("license", image.license),
                ("license_url", image.licenseURL),
                ("artist", image.artist),
                ("source_page_url", image.sourcePageURL),
                ("source_file_url", image.sourceFileURL),
            ]
            for (field, value) in required {
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !trimmed.isEmpty else {
                    throw ImportError.invalidImageField(slug: image.slug, field: field)
                }
            }
            guard let license = image.license, Self.allowedImageLicenses.contains(license)
            else {
                throw ImportError.disallowedImageLicense(
                    slug: image.slug, license: image.license ?? "")
            }
        }
    }

    func verifyNoOrphanImages(_ manifest: PlantImagesFile, in directory: URL) throws {
        let referenced = Set(manifest.images.compactMap(\.file))
        let contents: [String]
        do {
            contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        } catch {
            throw ImportError.missingImageDirectory(directory.lastPathComponent)
        }
        for name in contents.sorted() where !name.hasPrefix(".") {
            guard referenced.contains(name) else {
                throw ImportError.orphanImageFile(name)
            }
        }
    }

    func verifyImageFiles(_ manifest: PlantImagesFile) throws {
        guard let imagesDirectory else {
            throw ImportError.missingImageDirectory(Self.plantImagesFile)
        }
        try validateImageRecords(manifest)
        try verifyNoOrphanImages(manifest, in: imagesDirectory)
        for image in manifest.images {
            guard let file = image.file, let sha256 = image.sha256 else {
                throw ImportError.invalidImageField(slug: image.slug, field: "file")
            }
            let url = imagesDirectory.appendingPathComponent(file)
            guard let data = try? Data(contentsOf: url) else {
                throw ImportError.missingImageFile(file)
            }
            let actual = InputsLock.checksum(of: data)
            guard actual == sha256.lowercased() else {
                throw ImportError.checksumMismatch(
                    file: file, expected: sha256, actual: actual)
            }
        }
    }
}

extension KnowledgeMapper {
    func mapImages(
        _ taxonomy: Taxonomy,
        into mapped: inout MappedKnowledge
    ) throws {
        guard let manifest = inputs.images else { return }
        mapped.inputVersions[manifest.meta.name] = manifest.meta.version
        if let provenance = manifest.meta.provenance {
            mapped.inputProvenance[manifest.meta.name] = provenance
        }
        var cropBySpecies: [String: String] = [:]
        for (crop, speciesID) in taxonomy.speciesByCrop {
            cropBySpecies[speciesID] = crop
        }
        var owners: [String: String] = [:]
        for (crop, speciesID) in taxonomy.speciesByCrop {
            owners["species:\(crop)"] = speciesID
        }
        for cultivar in mapped.cultivars {
            guard let crop = cropBySpecies[cultivar.speciesID.rawValue] else { continue }
            let leaf = cultivar.id.rawValue.split(separator: "/").last.map(String.init) ?? ""
            owners["cultivar:\(crop)/\(leaf)"] = cultivar.id.rawValue
        }
        for image in manifest.images {
            guard let file = image.file, let sha256 = image.sha256, let license = image.license,
                let sourcePage = image.sourcePageURL, let sourceFile = image.sourceFileURL
            else {
                throw ImportError.invalidImageField(slug: image.slug, field: "file")
            }
            let key = "\(image.ownerKind.rawValue):\(image.slug)"
            guard let ownerID = owners[key] else {
                throw ImportError.unknownImageOwner(file: file, slug: image.slug)
            }
            mapped.images.append(
                MappedImage(
                    ownerKind: image.ownerKind.rawValue,
                    ownerID: ownerID,
                    relatedID: nil,
                    kind: image.kind,
                    file: file,
                    sha256: sha256.lowercased(),
                    license: license,
                    licenseURL: image.licenseURL,
                    artist: image.artist,
                    sourcePageURL: sourcePage,
                    sourceFileURL: sourceFile
                ))
        }
        mapped.images.sort { $0.sortKey < $1.sortKey }
        mapped.images = mapped.images.reduce(into: []) { result, image in
            if result.last?.sortKey != image.sortKey {
                result.append(image)
            }
        }
    }
}
