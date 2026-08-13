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

    var primaryKey: String {
        "\(ownerKind)|\(ownerID)|\(kind)|\(file)"
    }

    var sortKey: String {
        "\(primaryKey)|\(relatedID ?? "")"
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
            try validateKind(image)
        }
    }

    private func validateKind(_ image: PlantImageInput) throws {
        guard let kind = ImageKind(rawValue: image.kind) else {
            throw ImportError.disallowedImageKind(slug: image.slug, kind: image.kind)
        }
        guard kind.allowedOwners.contains(image.ownerKind) else {
            throw ImportError.imageKindOwnerMismatch(
                slug: image.slug, kind: image.kind, ownerKind: image.ownerKind.rawValue)
        }
        let related = image.relatedSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch kind.relatedRule {
        case .forbidden where !related.isEmpty:
            throw ImportError.unexpectedRelatedSlug(slug: image.slug, kind: image.kind)
        case .required where related.isEmpty:
            throw ImportError.missingRelatedSlug(slug: image.slug, kind: image.kind)
        default:
            break
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
