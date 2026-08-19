import GardenModel
import SwiftUI
import Today

import struct Domain.GeoCoordinate

private enum CoordinateFillFailure: Error {
    case unusableCoordinate
}

enum PropertyLocationFill {
    static let system: CoordinateFill = {
        let location = try await SystemLocationProvider().currentLocation()
        guard
            let coordinate = GeoCoordinate(
                latitude: location.latitude,
                longitude: location.longitude
            )
        else {
            throw CoordinateFillFailure.unusableCoordinate
        }
        return coordinate
    }
}

enum PropertyClimateHistory {
    static let years = 10

    static let system: HistoricalMinima = { coordinate in
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .year, value: -years, to: end) else {
            return []
        }
        return try await SystemWeatherProvider().dailyMinima(
            at: GeoLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            from: start,
            to: end
        )
    }
}

struct PropertySettingsView: View {
    @Environment(\.appStores) private var stores
    @State private var form: PropertyDetailsForm?
    @State private var saveCount = 0
    @State private var showsSaved = false

    var body: some View {
        Group {
            if let form, let message = form.loadFailureMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.secondary)
                    .padding(CroftTheme.space(6))
            } else if let form {
                editor(form)
            } else {
                Text("Property details are unavailable.")
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.secondary)
                    .padding(CroftTheme.space(6))
            }
        }
        .task {
            if form == nil, let database = stores?.database {
                let details = PropertyDetailsForm(
                    database: database,
                    fillCoordinate: PropertyLocationFill.system,
                    addressSearch: SystemAddressSearch(),
                    reverseGeocode: SystemAddressSearch.reverseGeocode,
                    minima: PropertyClimateHistory.system
                )
                details.load()
                form = details
            }
        }
        #if os(macOS)
            .frame(width: 460, height: 520)
        #endif
    }

    private func editor(_ form: PropertyDetailsForm) -> some View {
        VStack(spacing: 0) {
            PropertyDetailsView(form: form)
            HStack(spacing: CroftTheme.space(2)) {
                if showsSaved {
                    Text("Saved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .task(id: saveCount) {
                            try? await Task.sleep(for: .seconds(2))
                            showsSaved = false
                        }
                }
                Spacer()
                Button("Save") {
                    if form.save() {
                        saveCount += 1
                        showsSaved = true
                    } else {
                        showsSaved = false
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, CroftTheme.space(5))
            .padding(.bottom, CroftTheme.space(5))
        }
        .croftScreenSurface()
    }
}

struct PropertySetupSheet: View {
    let form: PropertyDetailsForm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(4)) {
            VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
                Text("Set up your property")
                    .font(CroftTheme.heading)
                Text(
                    "Tell Croft where your garden grows. Frost dates set your planting windows, "
                        + "and your location brings in the weather."
                )
                .font(CroftTheme.supporting)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, CroftTheme.space(5))
            .padding(.top, CroftTheme.space(6))
            PropertyDetailsView(form: form)
            HStack(spacing: CroftTheme.space(2)) {
                Spacer()
                Button("Not Now") {
                    dismiss()
                }
                Button("Save") {
                    if form.save() {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, CroftTheme.space(5))
            .padding(.bottom, CroftTheme.space(5))
        }
        .croftScreenSurface()
        #if os(macOS)
            .frame(width: 480, height: 600)
        #endif
    }
}
