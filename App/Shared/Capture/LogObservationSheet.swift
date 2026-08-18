import Capture
import Design
import SwiftUI
import UniformTypeIdentifiers

import enum Domain.LifecycleStage
import enum Domain.ObservationTarget

struct LogObservationSheet: View {
    @State private var form: LogObservationForm
    @State private var importing = false
    @State private var attachmentNote: String?
    @State private var choices: CaptureTargetChoices?
    @State private var prefilledLabel: String?
    let context: CaptureContext
    let onSaved: () -> Void

    init(
        context: CaptureContext,
        target: ObservationTarget?,
        stage: LifecycleStage? = nil,
        onSaved: @escaping () -> Void
    ) {
        self.context = context
        self.onSaved = onSaved
        let form = LogObservationForm(context: context, target: target)
        form.stage = stage
        _form = State(initialValue: form)
    }

    var body: some View {
        CaptureSheetScaffold(
            title: "Log Observation",
            confirm: "Save",
            canConfirm: form.canSave,
            minHeight: 380,
            commit: saveAction
        ) {
            targetPicker
            DatePicker("Observed", selection: $form.observedAt, displayedComponents: .date)
            Picker("Stage", selection: $form.stage) {
                Text("None").tag(LifecycleStage?.none)
                ForEach(LifecycleStage.allCases, id: \.self) { stage in
                    Text(stage.menuName).tag(LifecycleStage?.some(stage))
                }
            }
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
        .task(loadChoices)
    }

    private var targetPicker: some View {
        Picker("About", selection: $form.target) {
            if form.target == nil {
                Text("Pick a target").tag(ObservationTarget?.none)
            }
            if let prefilledLabel, let target = form.target, !contains(target) {
                Text(prefilledLabel).tag(ObservationTarget?.some(target))
            }
            if let choices {
                targetSection("Plantings", choices.plantings)
                targetSection("Beds", choices.beds)
                targetSection("Gardens", choices.gardens)
            }
        }
    }

    @ViewBuilder
    private func targetSection(_ title: String, _ entries: [CaptureTargetChoice]) -> some View {
        if !entries.isEmpty {
            Section(title) {
                ForEach(entries) { choice in
                    Text(choice.label).tag(ObservationTarget?.some(choice.target))
                }
            }
        }
    }

    private func contains(_ target: ObservationTarget) -> Bool {
        guard let choices else {
            return false
        }
        return (choices.plantings + choices.beds + choices.gardens)
            .contains { $0.target == target }
    }

    @Sendable
    private func loadChoices() async {
        choices = try? context.targetChoices()
        if let target = form.target, !contains(target) {
            prefilledLabel = (try? context.targetLabel(for: target)) ?? "Current selection"
        }
    }

    private var photoRow: some View {
        HStack(spacing: CroftTheme.space(3)) {
            Button {
                importing = true
            } label: {
                Label("Attach Photos…", systemImage: "photo.badge.plus")
            }
            #if os(macOS)
                Button {
                    pastePhotos()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
            #endif
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
        #if os(macOS)
            .onPasteCommand(of: [.image]) { _ in
                pastePhotos()
            }
        #endif
    }

    #if os(macOS)
        private func pastePhotos() {
            let pasteboard = NSPasteboard.general
            guard
                let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
                !images.isEmpty
            else {
                attachmentNote = "No image on the clipboard."
                return
            }
            var added = 0
            for image in images {
                guard let tiff = image.tiffRepresentation,
                    let bitmap = NSBitmapImageRep(data: tiff),
                    let png = bitmap.representation(using: .png, properties: [:])
                else {
                    continue
                }
                form.photos.append(png)
                added += 1
            }
            attachmentNote =
                added > 0
                ? "Pasted \(added) photo\(added == 1 ? "" : "s")."
                : "Couldn't read the clipboard image."
        }
    #endif

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
