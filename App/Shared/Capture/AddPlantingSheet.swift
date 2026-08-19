import Capture
import Design
import PlantCatalog
import SwiftUI

import struct Domain.Bed
import enum Domain.PlantIdentity
import enum Domain.PlantingSource
import struct Domain.SeedLot

struct AddPlantingSheet: View {
    @State private var form: AddPlantingForm
    @State private var query = ""
    @State private var choices: [PlantListItem] = []
    @State private var beds: [(bed: Bed, gardenName: String)] = []
    @State private var lots: [SeedLot] = []
    let context: CaptureContext
    let intent: AddPlantingIntent
    let onSaved: () -> Void

    init(context: CaptureContext, intent: AddPlantingIntent, onSaved: @escaping () -> Void) {
        self.context = context
        self.intent = intent
        self.onSaved = onSaved
        _form = State(
            initialValue: AddPlantingForm(
                context: context,
                bedID: intent.bedID,
                identity: intent.identity,
                planned: intent.planned
            )
        )
    }

    var body: some View {
        CaptureSheetScaffold(
            title: intent.planned ? "Plan Planting" : "Add Planting",
            confirm: intent.planned ? "Plan" : "Plant",
            canConfirm: form.canSave,
            minHeight: 460,
            commit: saveAction
        ) {
            plantPicker
            Picker("Bed", selection: $form.bedID) {
                Text("Pick a bed").tag(Bed.ID?.none)
                ForEach(beds, id: \.bed.id) { entry in
                    Text("\(entry.bed.name) · \(entry.gardenName)")
                        .tag(Bed.ID?.some(entry.bed.id))
                }
            }
            rotationAdvice
            if !lots.isEmpty {
                Picker("From seed lot", selection: $form.source) {
                    Text("None").tag(PlantingSource?.none)
                    ForEach(lots, id: \.id) { lot in
                        Text(lot.source ?? lot.id.rawValue)
                            .tag(PlantingSource?.some(.seedLot(lot.id)))
                    }
                }
            }
            HStack {
                TextField(
                    "Quantity",
                    value: $form.quantity, format: .number.precision(.fractionLength(0))
                )
                .frame(width: 120)
                if !intent.planned {
                    DatePicker("Planted", selection: $form.plantedOn, displayedComponents: .date)
                }
            }
            TextField("Notes", text: $form.notes, axis: .vertical)
                .lineLimit(2...3)
        }
        .task { load() }
        .onChange(of: form.identity) { _, _ in
            loadLots()
            form.refreshRotation()
        }
        .onChange(of: form.bedID) { _, _ in
            form.refreshRotation()
        }
    }

    @ViewBuilder
    private var rotationAdvice: some View {
        if let warning = form.rotationWarning {
            Label(
                "\(warning.familyName) was here in \(String(warning.year))",
                systemImage: "arrow.triangle.2.circlepath"
            )
            .font(.caption)
            .foregroundStyle(Color.domainHealth)
        }
        ForEach(form.companionNotes, id: \.plantName) { note in
            Label(
                companionLine(note),
                systemImage: note.isAntagonist
                    ? "exclamationmark.triangle" : "leaf"
            )
            .font(.caption)
            .foregroundStyle(note.isAntagonist ? Color.domainHealth : Color.domainGarden)
        }
        if !form.bedHistory.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(form.bedHistory, id: \.familyName) { line in
                    Text("\(line.familyName) grew here in \(String(line.mostRecentYear))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else if form.showsEmptyHistoryNote {
            Text("Nothing recorded here yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func companionLine(_ note: CompanionNote) -> String {
        note.isAntagonist
            ? "Antagonistic to the \(note.plantName) already here (\(note.source))"
            : "Companion of the \(note.plantName) already here (\(note.source))"
    }

    private var plantPicker: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            TextField("Search plants", text: $query)
                .textFieldStyle(.roundedBorder)
            List(filtered, selection: selectionBinding) { item in
                VStack(alignment: .leading) {
                    Text(item.displayName)
                    Text(item.scientificName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(item.identity)
            }
            .frame(minHeight: 160, maxHeight: 200)
        }
    }

    private var filtered: [PlantListItem] {
        PlantSearch.filter(choices, matching: query)
    }

    private var selectionBinding: Binding<PlantIdentity?> {
        Binding(get: { form.identity }, set: { form.identity = $0 })
    }

    private func load() {
        choices = (try? context.plantChoices()) ?? []
        beds = (try? context.activeBeds()) ?? []
        preselectQuery()
        loadLots()
        form.refreshRotation()
    }

    private func preselectQuery() {
        guard query.isEmpty, let identity = form.identity else {
            return
        }
        guard let preselected = choices.first(where: { $0.identity == identity }) else {
            return
        }
        query = preselected.displayName
    }

    private func loadLots() {
        if case .cultivar(let id) = form.identity {
            lots = (try? context.seedLots.lots(ofCultivar: id)) ?? []
        } else {
            lots = []
            form.source = nil
        }
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
