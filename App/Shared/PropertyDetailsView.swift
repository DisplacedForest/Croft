import Design
import GardenModel
import SwiftUI

import struct Domain.MonthDay

struct PropertyDetailsView: View {
    @Bindable var form: PropertyDetailsForm
    @State private var searchTask: Task<Void, Never>?
    @State private var ignoresQueryChange = false

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
            if form.canSearchAddresses {
                addressSearchField
            }
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

    @ViewBuilder private var addressSearchField: some View {
        TextField("Search address or place", text: $form.addressQuery)
            .onChange(of: form.addressQuery) { _, _ in
                searchTask?.cancel()
                guard !ignoresQueryChange else {
                    ignoresQueryChange = false
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else {
                        return
                    }
                    await form.searchAddresses()
                }
            }
        if !form.addressSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: CroftTheme.space(1)) {
                ForEach(form.addressSuggestions) { suggestion in
                    suggestionRow(suggestion)
                }
            }
        }
        if let confirmation = form.matchConfirmation {
            Text(confirmation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if let message = form.addressMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if form.isDerivingClimate {
            HStack(spacing: CroftTheme.space(2)) {
                ProgressView()
                    .controlSize(.small)
                Text("Deriving climate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func suggestionRow(_ suggestion: AddressSuggestion) -> some View {
        Button {
            searchTask?.cancel()
            ignoresQueryChange = true
            Task {
                await form.selectSuggestion(suggestion)
                ignoresQueryChange = false
            }
        } label: {
            VStack(alignment: .leading, spacing: CroftTheme.space(0.5)) {
                Text(suggestion.title)
                    .font(CroftTheme.supporting)
                if !suggestion.subtitle.isEmpty {
                    Text(suggestion.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var zoneSection: some View {
        Section("Hardiness Zone") {
            TextField("Zone", text: $form.zoneText)
            if form.derivedPrefilled.contains(.zone) {
                derivedCaption
            }
            if let zone = suggestedZone {
                suggestionOffer("Derived: \(zone)", field: .zone)
            }
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
            if hasDerivedFrost {
                derivedCaption
            }
            if let last = suggested(.lastFrost) {
                suggestionOffer("Derived: \(Self.label(for: last))", field: .lastFrost)
            }
            if let first = suggested(.firstFrost) {
                suggestionOffer("Derived: \(Self.label(for: first))", field: .firstFrost)
            }
        }
    }

    private var hasDerivedFrost: Bool {
        form.derivedPrefilled.contains(.lastFrost) || form.derivedPrefilled.contains(.firstFrost)
    }

    private var suggestedZone: Int? {
        guard form.climateSuggestions.contains(.zone) else {
            return nil
        }
        return form.derivedClimate?.zone
    }

    private func suggested(_ field: PropertyClimateField) -> MonthDay? {
        guard form.climateSuggestions.contains(field) else {
            return nil
        }
        return field == .lastFrost
            ? form.derivedClimate?.lastFrost : form.derivedClimate?.firstFrost
    }

    private var derivedCaption: some View {
        Text("Derived from ten years of weather at this location.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func suggestionOffer(_ title: String, field: PropertyClimateField) -> some View {
        HStack(spacing: CroftTheme.space(2)) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: CroftTheme.space(2))
            Button("Apply") {
                form.applySuggestion(field)
            }
        }
    }

    private static func label(for value: MonthDay) -> String {
        let symbols = Calendar.current.monthSymbols
        guard value.month >= 1, value.month <= symbols.count else {
            return "\(value.month)/\(value.day)"
        }
        return "\(symbols[value.month - 1]) \(value.day)"
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
