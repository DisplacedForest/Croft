import Design
import Persistence
import SwiftUI
import Today

import struct Domain.GardenTask

private struct GardenTaskStore: GardenTaskProviding {
    let repository: GardenTaskRepository

    func openTasks() throws -> [GardenTask] {
        try repository.openTasks()
    }

    func complete(id: GardenTask.ID, on date: Date) throws {
        try repository.complete(id: id, on: date)
    }
}

struct TodayView: View {
    @Environment(\.appStores) private var stores
    @Environment(CaptureStore.self) private var capture: CaptureStore?
    @State private var model = TodayViewModel(
        weatherProvider: SystemWeatherProvider(),
        locationProvider: SystemLocationProvider()
    )
    @State private var tasks: TodayTasksModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CroftTheme.space(6)) {
                clock
                weatherBlock
                gardenBlock
            }
            .padding(CroftTheme.space(8))
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: capture?.saveCount) { _, _ in
            tasks?.refresh()
        }
        .task {
            await model.loadWeather()
        }
        .task {
            if tasks == nil, let database = stores?.database {
                let tasksModel = TodayTasksModel(
                    provider: GardenTaskStore(repository: GardenTaskRepository(database))
                )
                tasksModel.refresh()
                tasks = tasksModel
            }
        }
        .task {
            await model.startClock()
        }
    }

    private var clock: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(1)) {
            Text(model.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(CroftTheme.display)
            Text(model.now, format: .dateTime.hour().minute())
                .font(CroftTheme.heading)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var weatherBlock: some View {
        if case .loaded(let snapshot) = model.weather {
            VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
                Label(snapshot.conditionDescription, systemImage: snapshot.symbolName)
                    .font(CroftTheme.heading)
                    .foregroundStyle(Color.domainWater)
                Text(
                    snapshot.temperature, format: .measurement(width: .abbreviated, usage: .weather)
                )
                .font(CroftTheme.display)
                attribution
            }
            .padding(CroftTheme.space(5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.domainWater.opacity(0.12),
                in: RoundedRectangle(cornerRadius: CroftTheme.space(3))
            )
        }
    }

    @ViewBuilder private var attribution: some View {
        HStack(spacing: CroftTheme.space(2)) {
            Label(" Weather", systemImage: "apple.logo")
                .labelStyle(.titleOnly)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
                Link("Legal", destination: url)
                    .font(.caption)
                    .foregroundStyle(Color.domainWater)
            }
        }
    }

    private var gardenBlock: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            Text("In the garden")
                .font(CroftTheme.heading)
                .foregroundStyle(Color.domainGarden)
            if let tasks, !tasks.isEmpty {
                if !tasks.overdue.isEmpty {
                    taskGroup("Overdue", tasks.overdue, model: tasks, showsDueDate: true)
                }
                if !tasks.dueToday.isEmpty {
                    taskGroup("Today", tasks.dueToday, model: tasks, showsDueDate: false)
                }
            } else {
                Text("Nothing needs doing today.")
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(CroftTheme.space(5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.domainGarden.opacity(0.12),
            in: RoundedRectangle(cornerRadius: CroftTheme.space(3))
        )
    }

    private func taskGroup(
        _ title: String,
        _ group: [GardenTask],
        model: TodayTasksModel,
        showsDueDate: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(showsDueDate ? Color.domainHealth : Color.domainGarden)
                .textCase(.uppercase)
            ForEach(group, id: \.id) { item in
                taskRow(item, model: model, showsDueDate: showsDueDate)
            }
        }
    }

    private func taskRow(
        _ item: GardenTask,
        model: TodayTasksModel,
        showsDueDate: Bool
    ) -> some View {
        HStack(spacing: CroftTheme.space(2)) {
            Button {
                model.complete(item)
            } label: {
                Image(systemName: "circle")
                    .foregroundStyle(Color.domainGarden)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(item.title)")
            Text(item.title)
                .font(CroftTheme.supporting)
            Spacer()
            if showsDueDate, let due = item.dueOn {
                Text(due, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                    .foregroundStyle(Color.domainHealth)
            }
        }
    }
}
