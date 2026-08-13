import Foundation
import Knowledge

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func runSanitize(kind: String, raw: String, output: String) {
    do {
        let rawData = try Data(contentsOf: URL(fileURLWithPath: raw))
        let sanitized =
            switch kind {
            case "catalog":
                try CatalogSanitizer.sanitize(rawCatalog: rawData)
            case "pest-disease":
                try CatalogSanitizer.sanitize(rawPestDisease: rawData)
            default:
                throw SanitizerError.unexpectedShape("unknown sanitize kind \(kind)")
            }
        try sanitized.write(to: URL(fileURLWithPath: output), options: .atomic)
        print("sanitized \(raw)")
        print("  raw sha256: \(InputsLock.checksum(of: rawData))")
        print("  sanitized sha256: \(InputsLock.checksum(of: sanitized))")
        print("  wrote \(output)")
    } catch {
        fail("sanitize failed: \(error)")
    }
}

func runBuild(inputs: String, output: String) {
    let importer = KnowledgeImporter(inputDirectory: URL(fileURLWithPath: inputs))
    do {
        let summary = try importer.buildSnapshot(at: URL(fileURLWithPath: output))
        print("built \(output)")
        for (key, value) in summary.counts.sorted(by: { $0.key < $1.key }) {
            print("  \(key): \(value)")
        }
        for (key, value) in summary.skips.sorted(by: { $0.key < $1.key }) {
            print("  skipped \(key): \(value)")
        }
        for (key, value) in summary.normalizations.sorted(by: { $0.key < $1.key }) {
            print("  normalized \(key): \(value)")
        }
    } catch {
        fail("import failed: \(error)")
    }
}

func runAttribution(snapshot: String, output: String) {
    do {
        let markdown = try AttributionWriter.markdown(
            for: URL(fileURLWithPath: snapshot))
        try Data(markdown.utf8).write(to: URL(fileURLWithPath: output), options: .atomic)
        print("wrote \(output)")
    } catch {
        fail("attribution failed: \(error)")
    }
}

func runDump(snapshot: String) {
    do {
        print(try KnowledgeSnapshot.logicalDump(at: URL(fileURLWithPath: snapshot)))
    } catch {
        fail("dump failed: \(error)")
    }
}

let arguments = CommandLine.arguments
switch (arguments.count, arguments.dropFirst().first) {
case (5, "sanitize"):
    runSanitize(kind: arguments[2], raw: arguments[3], output: arguments[4])
case (4, "build"):
    runBuild(inputs: arguments[2], output: arguments[3])
case (4, "attribution"):
    runAttribution(snapshot: arguments[2], output: arguments[3])
case (3, "dump"):
    runDump(snapshot: arguments[2])
default:
    fail(
        """
        usage:
          knowledge-importer sanitize catalog|pest-disease <raw.json> <output.json>
          knowledge-importer build <inputs-dir> <snapshot.sqlite>
          knowledge-importer attribution <snapshot.sqlite> <output.md>
          knowledge-importer dump <snapshot.sqlite>
        """
    )
}
