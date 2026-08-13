import Capture
import SwiftUI

import struct Domain.GardenTask
import enum Domain.GardenTaskType

struct TasksSheet: View {
    @State private var checklist: TaskChecklist
    @State private var adding = false
    let context: CaptureContext
    let onSaved: () -> Void

    init(context: CaptureContext, onSaved: @escaping () -> Void) {
        self.context = context
        self.onSaved = onSaved
        _checklist = State(initialValue: TaskChecklist(context: context))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(4)) {
            HStack {
                Text("Tasks")
                    .font(CroftTheme.heading)
                Spacer()
                Button {
                    adding = true
                } label: {
                    Label("New Task", systemImage: "plus")
                }
                .keyboardShortcut("n")
            }
            if checklist.open.isEmpty {
                ContentUnavailableView(
                    "All caught up",
                    systemImage: "checkmark.circle",
                    description: Text("New tasks appear here until you complete them.")
                )
            } else {
                List(checklist.open, id: \.id) { task in
                    taskRow(task)
                }
            }
            HStack {
                Spacer()
                Button("Done") {
                    dismissAction()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(CroftTheme.space(6))
        .frame(minWidth: 440, maxWidth: 540, minHeight: 380)
        .sheet(isPresented: $adding) {
            AddTaskSheet(context: context) {
                checklist.refresh()
                onSaved()
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private func dismissAction() {
        dismiss()
    }

    private func taskRow(_ task: GardenTask) -> some View {
        HStack(spacing: CroftTheme.space(3)) {
            Button {
                checklist.complete(task.id)
                onSaved()
            } label: {
                Image(systemName: "circle")
            }
            .buttonStyle(.plain)
            .help("Mark complete")
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                if let due = task.dueOn {
                    Text("due \(due.gardenDisplay)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

struct AddTaskSheet: View {
    @State private var form: AddTaskForm
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    let onSaved: () -> Void

    init(context: CaptureContext, onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
        _form = State(initialValue: AddTaskForm(context: context))
    }

    var body: some View {
        CaptureSheetScaffold(
            title: "New Task",
            confirm: "Add",
            canConfirm: form.canSave,
            commit: saveAction
        ) {
            TextField("Title", text: $form.title, prompt: Text("Water the tomatoes"))
                .textFieldStyle(.roundedBorder)
            Picker("Kind", selection: $form.type) {
                ForEach(GardenTaskType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            if form.type == .other {
                TextField("Custom kind", text: $form.customType)
                    .textFieldStyle(.roundedBorder)
            }
            Toggle("Due date", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker("Due", selection: $dueDate, displayedComponents: .date)
            }
        }
    }

    private func saveAction() -> Bool {
        form.dueOn = hasDueDate ? dueDate : nil
        do {
            try form.save()
            onSaved()
            return true
        } catch {
            return false
        }
    }
}
