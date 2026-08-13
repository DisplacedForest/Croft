import Design
import PlantCatalog
import SwiftUI

@MainActor
enum PlantImageAsset {
    private static var cache: [String: Image?] = [:]

    static func url(for file: String) -> URL? {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        guard !name.isEmpty else { return nil }
        let type = ext.isEmpty ? nil : ext
        return Bundle.main.url(forResource: name, withExtension: type, subdirectory: "PlantImages")
            ?? Bundle.main.url(forResource: name, withExtension: type)
    }

    static func image(named file: String?) -> Image? {
        guard let file, !file.isEmpty else { return nil }
        if let cached = cache[file] {
            return cached
        }
        let loaded = load(file)
        cache[file] = loaded
        return loaded
    }

    private static func load(_ file: String) -> Image? {
        guard let url = url(for: file), let data = try? Data(contentsOf: url) else { return nil }
        #if os(macOS)
            guard let platformImage = NSImage(data: data) else { return nil }
            return Image(nsImage: platformImage)
        #else
            guard let platformImage = UIImage(data: data) else { return nil }
            return Image(uiImage: platformImage)
        #endif
    }
}

struct PlantImageView: View {
    let file: String?
    var cornerRadius: CGFloat = CroftTheme.space(3)

    var body: some View {
        Group {
            if let image = PlantImageAsset.image(named: file) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color.domainGarden.opacity(0.14)
            Image(systemName: "leaf")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color.domainGarden.opacity(0.55))
        }
    }
}

struct PlantHeaderImage: View {
    let image: PlantImage?
    @State private var showingCredit = false

    var body: some View {
        PlantImageView(file: image?.file, cornerRadius: CroftTheme.space(4))
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .overlay(alignment: .bottomTrailing) {
                if let image {
                    creditButton(for: image)
                }
            }
    }

    private func creditButton(for image: PlantImage) -> some View {
        Button {
            showingCredit = true
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.body)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.45))
                .padding(CroftTheme.space(2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Photo credit")
        .popover(isPresented: $showingCredit, arrowEdge: .bottom) {
            PlantImageCreditView(image: image)
        }
    }
}

struct PlantThreatThumbnail: View {
    let image: PlantImage?
    var side: CGFloat = 44
    @State private var showingCredit = false

    var body: some View {
        if let image {
            Button {
                showingCredit = true
            } label: {
                thumbnail(file: image.file)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Photo credit")
            .popover(isPresented: $showingCredit, arrowEdge: .bottom) {
                PlantImageCreditView(image: image)
            }
        } else {
            thumbnail(file: nil)
        }
    }

    private func thumbnail(file: String?) -> some View {
        PlantImageView(file: file, cornerRadius: CroftTheme.space(2))
            .frame(width: side, height: side)
    }
}

struct PlantImageCreditView: View {
    let image: PlantImage

    var body: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            if let artist = image.artist {
                Text(artist)
                    .font(.body.weight(.medium))
            }
            licenseLine
            if let page = URL(string: image.sourcePageURL) {
                Link("View source", destination: page)
                    .font(CroftTheme.supporting)
            }
        }
        .padding(CroftTheme.space(4))
        .frame(width: 260, alignment: .leading)
    }

    @ViewBuilder private var licenseLine: some View {
        if let licenseURL = image.licenseURL.flatMap(URL.init(string:)) {
            Link(image.license, destination: licenseURL)
                .font(CroftTheme.supporting)
        } else {
            Text(image.license)
                .font(CroftTheme.supporting)
                .foregroundStyle(.secondary)
        }
    }
}
