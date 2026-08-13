import Capture
import SwiftUI

struct CaptureSheetHost: ViewModifier {
    @Environment(CaptureStore.self) private var capture

    func body(content: Content) -> some View {
        @Bindable var capture = capture
        return
            content
            .sheet(item: $capture.activeSheet) { sheet in
                if let context = capture.context {
                    sheetView(sheet, context: context)
                } else {
                    ContentUnavailableView(
                        "Records unavailable",
                        systemImage: "externaldrive.badge.exclamationmark",
                        description: Text("Croft couldn't open its database.")
                    )
                    .padding()
                }
            }
    }

    @ViewBuilder
    private func sheetView(_ sheet: CaptureSheet, context: CaptureContext) -> some View {
        switch sheet {
        case .addPlanting(let bedID):
            AddPlantingSheet(context: context, bedID: bedID, onSaved: capture.didSave)
        case .logObservation(let target):
            LogObservationSheet(context: context, target: target, onSaved: capture.didSave)
        case .recordHarvest(let plantingID):
            RecordHarvestSheet(
                context: context, plantingID: plantingID, onSaved: capture.didSave)
        case .tasks:
            TasksSheet(context: context, onSaved: capture.didSave)
        case .addSeedLot:
            AddSeedLotSheet(context: context, onSaved: capture.didSave)
        }
    }
}

struct CaptureMenu: View {
    @Environment(CaptureStore.self) private var capture

    var body: some View {
        Menu {
            Button("Add Planting…") { capture.present(.addPlanting(nil)) }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Add Seed Lot…") { capture.present(.addSeedLot) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Tasks…") { capture.present(.tasks) }
                .keyboardShortcut("t", modifiers: [.command, .shift])
        } label: {
            Label("Record", systemImage: "plus.circle.fill")
        }
    }
}

struct CaptureSheetScaffold<Content: View>: View {
    let title: String
    let confirm: String
    let canConfirm: Bool
    var minHeight: CGFloat = 300
    let commit: () -> Bool
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(4)) {
            Text(title)
                .font(CroftTheme.heading)
            content()
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(confirm) {
                    if commit() {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canConfirm)
            }
            .padding(.top, CroftTheme.space(2))
        }
        .padding(CroftTheme.space(6))
        .frame(minWidth: 420, maxWidth: 520, minHeight: minHeight)
    }
}
