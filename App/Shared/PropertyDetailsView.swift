import Design
import GardenModel
import SwiftUI

import struct Domain.MonthDay

struct PropertyDetailsView: View {
    @Bindable var form: PropertyDetailsForm
    @State private var searchTask: Task<Void, Never>?
    @State private var deriveTask: Task<Void, Never>?
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
                .onChange(of: form.latitudeText) { _, _ in
                    scheduleDerive()
                }
            TextField("Longitude", text: $form.longitudeText)
                .onChange(of: form.longitudeText) { _, _ in
                    scheduleDerive()
                }
            if form.canFillLocation {
                HStack(spacing: CroftTheme.space(2)) {
                    Button("Use Current Location") {
                        searchTask?.cancel()
                        ignoresQueryChange = true
                        Task {
                            await form.useCurrentLocation()
                            ignoresQueryChange = false
                        }
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
        if let message = form.derivationMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func scheduleDerive() {
        deriveTask?.cancel()
        deriveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else {
                return
            }
            await form.deriveClimate()
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
            if form.zoneSource == .user {
                TextField("Zone", text: $form.zoneText)
                caption("Custom")
                sourceButton(
                    "Use Derived Value",
                    accessibility: "Use derived hardiness zone"
                ) {
                    await form.useDerivedZone()
                }
            } else {
                LabeledContent("Zone", value: zoneDisplay)
                caption(derivedMark)
                adjustButton(accessibility: "Adjust hardiness zone") {
                    form.adjustZone()
                }
            }
        }
    }

    private var frostSection: some View {
        Section("Frost Dates") {
            if form.frostDatesSource == .user {
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
                caption("Custom")
                sourceButton(
                    "Use Derived Values",
                    accessibility: "Use derived frost dates"
                ) {
                    await form.useDerivedFrostDates()
                }
            } else {
                LabeledContent(
                    "Last frost",
                    value: frostDisplay(form.lastFrostMonth, form.lastFrostDay))
                LabeledContent(
                    "First frost",
                    value: frostDisplay(form.firstFrostMonth, form.firstFrostDay))
                caption(derivedMark)
                adjustButton(accessibility: "Adjust frost dates") {
                    form.adjustFrostDates()
                }
            }
        }
    }

}

extension PropertyDetailsView {
    private var zoneDisplay: String {
        form.zoneText.isEmpty ? "Not set" : form.zoneText
    }

    private func frostDisplay(_ month: Int?, _ day: Int?) -> String {
        guard let month, let day, let value = MonthDay(month: month, day: day) else {
            return "Not set"
        }
        return Self.label(for: value)
    }

    private var derivedMark: String {
        form.derivationMessage ?? "Derived"
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func adjustButton(
        accessibility: String, action: @escaping () -> Void
    ) -> some View {
        Button("Adjust", action: action)
            .accessibilityLabel(accessibility)
    }

    private func sourceButton(
        _ title: String, accessibility: String, action: @escaping () async -> Void
    ) -> some View {
        Button(title) {
            Task {
                await action()
            }
        }
        .accessibilityLabel(accessibility)
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
                Picker("\(title) day", selection: day) {
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
