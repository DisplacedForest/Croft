import Capture
import PlantCatalog
import SwiftUI

import struct Domain.Cultivar
import enum Domain.PlantIdentity

struct AddSeedLotSheet: View {
    @State private var form: AddSeedLotForm
    @State private var query = ""
    @State private var choices: [PlantListItem] = []
    let context: CaptureContext
    let onSaved: () -> Void

    init(context: CaptureContext, onSaved: @escaping () -> Void) {
        self.context = context
        self.onSaved = onSaved
        _form = State(initialValue: AddSeedLotForm(context: context))
    }

    var body: some View {
        CaptureSheetScaffold(
            title: "Add Seed Lot",
            confirm: "Add",
            canConfirm: form.canSave,
            minHeight: 440,
            commit: saveAction
        ) {
            TextField("Search cultivars", text: $query)
                .textFieldStyle(.roundedBorder)
            List(cultivarChoices, selection: selectionBinding) { item in
                VStack(alignment: .leading) {
                    Text(item.displayName)
                    Text(item.scientificName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(cultivarID(of: item))
            }
            .frame(minHeight: 150, maxHeight: 190)
            TextField("Source", text: $form.source, prompt: Text("Baker Creek, seed swap…"))
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("Amount", text: $form.quantityText, prompt: Text("1 packet"))
                    .textFieldStyle(.roundedBorder)
                TextField("Seed count", text: $form.seedCountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
            }
            DatePicker("Acquired", selection: $form.acquiredOn, displayedComponents: .date)
        }
        .task {
            choices = (try? context.plantChoices()) ?? []
        }
    }

    private var cultivarChoices: [PlantListItem] {
        PlantSearch.filter(choices, matching: query).filter { $0.kind == .cultivar }
    }

    private func cultivarID(of item: PlantListItem) -> Cultivar.ID? {
        if case .cultivar(let id) = item.identity {
            return id
        }
        return nil
    }

    private var selectionBinding: Binding<Cultivar.ID?> {
        Binding(get: { form.cultivarID }, set: { form.cultivarID = $0 })
    }

    private func saveAction() -> Bool {
        do {
            try form.save()
            onSaved()
            return true
        } catch {
            return false
        }
    }
}
