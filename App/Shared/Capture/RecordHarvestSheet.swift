import Capture
import SwiftUI

import enum Domain.HarvestQuality
import enum Domain.HarvestUnit
import struct Domain.Planting

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
                Picker("Unit", selection: $form.unit) {
                    ForEach(HarvestUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue.capitalized).tag(unit)
                    }
                }
                .labelsHidden()
            }
            if form.unit == .custom {
                TextField("Custom unit (baskets, heads…)", text: $form.customUnit)
                    .textFieldStyle(.roundedBorder)
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
