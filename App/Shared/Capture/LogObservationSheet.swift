import Capture
import Design
import SwiftUI
import UniformTypeIdentifiers

import enum Domain.ObservationTarget

struct LogObservationSheet: View {
    @State private var form: LogObservationForm
    @State private var importing = false
    @State private var attachmentNote: String?
    let onSaved: () -> Void

    init(context: CaptureContext, target: ObservationTarget, onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
        _form = State(initialValue: LogObservationForm(context: context, target: target))
    }

    var body: some View {
        CaptureSheetScaffold(
            title: "Log Observation",
            confirm: "Save",
            canConfirm: form.canSave,
            minHeight: 360,
            commit: saveAction
        ) {
            DatePicker("Observed", selection: $form.observedAt, displayedComponents: .date)
            TextField("What did you notice?", text: $form.notes, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.roundedBorder)
            photoRow
            if let attachmentNote {
                Text(attachmentNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let message = form.validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true,
            onCompletion: attach(result:)
        )
    }

    private var photoRow: some View {
        HStack(spacing: CroftTheme.space(3)) {
            Button {
                importing = true
            } label: {
                Label("Attach Photos…", systemImage: "photo.badge.plus")
            }
            if !form.photos.isEmpty {
                Text("\(form.photos.count) attached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(CroftTheme.space(3))
        .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10))
        .dropDestination(for: Data.self) { items, _ in
            form.photos.append(contentsOf: items)
            attachmentNote = "Dropped \(items.count) photo\(items.count == 1 ? "" : "s")."
            return !items.isEmpty
        }
    }

    private func attach(result: Result<[URL], any Error>) {
        guard case .success(let urls) = result else {
            return
        }
        var added = 0
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            if let data = try? Data(contentsOf: url) {
                form.photos.append(data)
                added += 1
            }
        }
        attachmentNote = added == urls.count ? nil : "Some photos couldn't be read."
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
