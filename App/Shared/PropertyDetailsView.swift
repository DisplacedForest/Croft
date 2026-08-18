import Design
import GardenModel
import SwiftUI

import struct Domain.MonthDay

struct PropertyDetailsView: View {
    @Bindable var form: PropertyDetailsForm

    var body: some View {
        Form {
            if let message = form.validationMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(CroftTheme.supporting)
                        .foregroundStyle(Color.domainHealth)
                }
            }
            locationSection
            zoneSection
            frostSection
        }
        .formStyle(.grouped)
    }

    private var locationSection: some View {
        Section("Location") {
            TextField("Latitude", text: $form.latitudeText)
            TextField("Longitude", text: $form.longitudeText)
            if form.canFillLocation {
                HStack(spacing: CroftTheme.space(2)) {
                    Button("Use Current Location") {
                        Task { await form.useCurrentLocation() }
                    }
                    .disabled(form.isFillingLocation)
                    if form.isFillingLocation {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            if let message = form.locationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var zoneSection: some View {
        Section("Hardiness Zone") {
            TextField("Zone", text: $form.zoneText)
            Text("Shown for reference. Planting windows use your frost dates.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var frostSection: some View {
        Section("Frost Dates") {
            frostRow(
                "Last frost",
                month: $form.lastFrostMonth,
                day: $form.lastFrostDay
            )
            frostRow(
                "First frost",
                month: $form.firstFrostMonth,
                day: $form.firstFrostDay
            )
        }
    }

    private func frostRow(
        _ title: String,
        month: Binding<Int?>,
        day: Binding<Int?>
    ) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            Picker(title, selection: month) {
                Text("None").tag(Int?.none)
                ForEach(monthChoices) { choice in
                    Text(choice.name).tag(Int?.some(choice.number))
                }
            }
            if let selected = month.wrappedValue, let last = MonthDay.lastDay(ofMonth: selected) {
                Picker("Day", selection: day) {
                    Text("None").tag(Int?.none)
                    ForEach(1...last, id: \.self) { value in
                        Text(String(value)).tag(Int?.some(value))
                    }
                }
            }
        }
        .onChange(of: month.wrappedValue) { _, newValue in
            clamp(month: newValue, day: day)
        }
    }

    private var monthChoices: [MonthChoice] {
        Calendar.current.monthSymbols.enumerated().map { index, name in
            MonthChoice(number: index + 1, name: name)
        }
    }

    private func clamp(month: Int?, day: Binding<Int?>) {
        guard let month, let last = MonthDay.lastDay(ofMonth: month) else {
            day.wrappedValue = nil
            return
        }
        if let current = day.wrappedValue, current > last {
            day.wrappedValue = last
        }
    }
}

private struct MonthChoice: Identifiable {
    let number: Int
    let name: String

    var id: Int { number }
}
