import Domain
import SwiftUI

struct NameEntrySheet: View {
    let title: String
    var prompt: String = ""
    var initialName: String = ""
    let confirm: String
    let commit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        SheetScaffold(title: title, confirm: confirm, canConfirm: canConfirm) {
            commit(name)
        } content: {
            TextField("Name", text: $name, prompt: prompt.isEmpty ? nil : Text(prompt))
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if canConfirm {
                        commit(name)
                        dismiss()
                    }
                }
        }
        .onAppear { name = initialName }
    }

    private var canConfirm: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct NewBedSheet: View {
    let commit: (String, BedKind) -> Void
    @State private var name = ""
    @State private var kind: BedKind = .raised

    var body: some View {
        SheetScaffold(title: "New Bed", confirm: "Create", canConfirm: canConfirm) {
            commit(name, kind)
        } content: {
            TextField(
                "Name", text: $name,
                prompt: Text("Long Bed, Herb Bed, Big Pot…")
            )
            .textFieldStyle(.roundedBorder)
            Picker("Kind", selection: $kind) {
                ForEach(BedKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var canConfirm: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct SheetScaffold<Content: View>: View {
    let title: String
    let confirm: String
    let canConfirm: Bool
    let commit: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(4)) {
            Text(title)
                .font(CroftTheme.heading)
            content()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button(confirm) {
                    commit()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canConfirm)
            }
            .padding(.top, CroftTheme.space(2))
        }
        .padding(CroftTheme.space(6))
        .frame(minWidth: 320, maxWidth: 420)
        .presentationDetents([.height(220)])
    }
}
