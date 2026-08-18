import Capture
import SwiftUI

import enum Domain.HarvestQuality
import enum Domain.HarvestablePart
import struct Domain.Planting
import enum Domain.QuantityUnit

struct RecordHarvestSheet: View {
    @State private var form: RecordHarvestForm
    @Environment(\.dismiss) private var dismiss
    let onSaved: () -> Void

    init(context: CaptureContext, plantingID: Planting.ID, onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
        _form = State(initialValue: RecordHarvestForm(context: context, plantingID: plantingID))
    }

    var body: some View {
        CaptureSheetScaffold(
            title: "Record Harvest",
            confirm: "Save",
            canConfirm: form.canSave,
            minHeight: 340,
            commit: saveOnce
        ) {
            HStack {
                TextField("Quantity", text: $form.quantityText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Picker("Unit", selection: $form.unitChoice) {
                    ForEach(form.unitChoices, id: \.self) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                .labelsHidden()
            }
            if form.unitChoice == .custom {
                TextField("Custom unit (baskets, heads…)", text: $form.customUnit)
                    .textFieldStyle(.roundedBorder)
            }
            if !form.partChoices.isEmpty {
                Picker("Part", selection: $form.harvestedPart) {
                    Text("Unspecified").tag(HarvestablePart?.none)
                    ForEach(form.partChoices, id: \.self) { part in
                        Text(part.rawValue.capitalized).tag(HarvestablePart?.some(part))
                    }
                }
            }
            Picker("Quality", selection: $form.quality) {
                Text("Unrated").tag(HarvestQuality?.none)
                ForEach(HarvestQuality.allCases, id: \.self) { quality in
                    Text(quality.rawValue.capitalized).tag(HarvestQuality?.some(quality))
                }
            }
            DatePicker("Harvested", selection: $form.harvestedOn, displayedComponents: .date)
            TextField("Notes", text: $form.notes, axis: .vertical)
                .lineLimit(2...3)
            HStack {
                if form.savedCount > 0 {
                    Text("\(form.savedCount) saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Save and Log Another") {
                    if save(dismissAfter: false) {
                        form.prepareForAnother()
                    }
                }
                .disabled(!form.canSave)
            }
        }
    }

    private func saveOnce() -> Bool {
        save(dismissAfter: false)
    }

    @discardableResult
    private func save(dismissAfter: Bool) -> Bool {
        do {
            try form.save()
            onSaved()
            if dismissAfter {
                dismiss()
            }
            return true
        } catch {
            return false
        }
    }
}

extension HarvestUnitChoice {
    var displayName: String {
        switch self {
        case .unit(let unit): unit.entryName
        case .custom: "Custom"
        }
    }
}

extension QuantityUnit {
    var entryName: String {
        switch self {
        case .gram: "Grams"
        case .kilogram: "Kilograms"
        case .ounce: "Ounces"
        case .pound: "Pounds"
        case .milliliter: "Milliliters"
        case .liter: "Liters"
        case .fluidOunce: "Fluid ounces"
        case .cup: "Cups"
        case .pint: "Pints"
        case .quart: "Quarts"
        case .gallon: "Gallons"
        case .count: "Count"
        }
    }
}
