import Design
import Domain
import PlantCatalog
import SwiftUI

struct ThreatRow: View {
    let threat: PlantThreat
    @State private var showingDetail = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: CroftTheme.space(3)) {
                PlantImageView(file: threat.image?.file, cornerRadius: CroftTheme.space(2))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: CroftTheme.space(0.5)) {
                    Text(threat.name)
                        .font(.body.weight(.medium))
                    if let agentName = threat.agentName {
                        Text(agentName)
                            .font(.callout.italic())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingDetail, arrowEdge: .trailing) {
            ThreatDetailView(threat: threat)
        }
    }
}

struct ThreatDetailView: View {
    let threat: PlantThreat

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
                if let image = threat.image {
                    PlantImageView(file: image.file, cornerRadius: CroftTheme.space(3))
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                }
                HStack(spacing: CroftTheme.space(2)) {
                    Text(threat.name)
                        .font(CroftTheme.heading)
                    Text(threat.kind.displayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, CroftTheme.space(1.5))
                        .padding(.vertical, CroftTheme.space(0.5))
                        .background(Color.domainHealth.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.domainHealth)
                }
                if let agentName = threat.agentName {
                    Text(agentName)
                        .font(.callout.italic())
                        .foregroundStyle(.secondary)
                }
                if let summary = threat.summary {
                    Text(summary)
                        .font(.body)
                }
                if !threat.affectedParts.isEmpty {
                    Text(
                        "Affects \(threat.affectedParts.map(\.displayName).joined(separator: ", ").lowercased())"
                    )
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.secondary)
                }
                if let image = threat.image {
                    Divider()
                    credit(for: image)
                }
            }
            .padding(CroftTheme.space(4))
        }
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 360)
        .frame(maxHeight: 440)
    }

    @ViewBuilder private func credit(for image: PlantImage) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(1)) {
            if let artist = image.artist {
                Text("Photo: \(artist)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let licenseURL = image.licenseURL.flatMap(URL.init(string:)) {
                Link(image.license, destination: licenseURL)
                    .font(.caption)
            } else {
                Text(image.license)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let page = URL(string: image.sourcePageURL) {
                Link("View source", destination: page)
                    .font(.caption)
            }
        }
    }
}
