import Design
import Persistence
import SwiftUI
import Today

struct TodayView: View {
    @Environment(\.appStores) private var stores
    @Environment(CaptureStore.self) private var capture: CaptureStore?
    @State private var model: TodayViewModel?
    @State private var feed: TodayFeedStore?
    @State private var showingForecast = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CroftTheme.space(6)) {
                if let model {
                    header(model)
                }
                if let feed {
                    if feed.items.isEmpty {
                        quietBlock(feed)
                    } else {
                        attentionCard(feed)
                    }
                    if !feed.recentLines.isEmpty {
                        recentlyCard(feed)
                    }
                }
            }
            .padding(CroftTheme.space(8))
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: capture?.saveCount) { _, _ in
            feed?.refresh()
        }
        .task {
            let ready = readyModel()
            async let clock: Void = ready.startClock()
            await ready.loadWeather()
            await recordTodayWeather()
            await clock
        }
        .task {
            if feed == nil {
                let store = TodayFeedStore(stores: stores)
                store.refresh()
                feed = store
                await store.loadFrostForecast()
            }
        }
    }

    private func readyModel() -> TodayViewModel {
        if let model {
            return model
        }
        let database = stores?.database
        let built = TodayViewModel(
            weatherProvider: SystemWeatherProvider(),
            locationProvider: StoredFirstLocationProvider(
                stored: { storedLocation(in: database) },
                fallback: SystemLocationProvider()
            ),
            forecastProvider: SystemWeatherProvider()
        )
        model = built
        return built
    }

    private func recordTodayWeather() async {
        guard let database = stores?.database,
            let property = try? GardenStructureRepository(database).properties().first
        else {
            return
        }
        let recorder = WeatherHistoryRecorder(
            provider: SystemWeatherProvider(),
            store: DailyWeatherRepository(database)
        )
        await recorder.recordToday(for: property)
    }

    private func header(_ model: TodayViewModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: CroftTheme.space(1)) {
                Text(model.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(CroftTheme.heading)
                Text(model.now, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: CroftTheme.space(4))
            weatherChip(model)
        }
    }

    @ViewBuilder private func weatherChip(_ model: TodayViewModel) -> some View {
        if case .loaded(let snapshot) = model.weather {
            Button {
                showingForecast = true
            } label: {
                HStack(spacing: CroftTheme.space(2)) {
                    Image(systemName: snapshot.symbolName)
                        .foregroundStyle(Color.domainWater)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(
                            snapshot.temperature,
                            format: .measurement(width: .abbreviated, usage: .weather)
                        )
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.domainWater)
                        Text(snapshot.conditionDescription)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, CroftTheme.space(2))
                .padding(.horizontal, CroftTheme.space(3))
                .background(
                    Color.domainWater.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: CroftTheme.space(3))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Seven day forecast")
            .popover(isPresented: $showingForecast, arrowEdge: .bottom) {
                ForecastPopover(model: model)
            }
        } else if case .unavailable(let reason) = model.weather {
            HStack(spacing: CroftTheme.space(2)) {
                Image(systemName: "cloud.slash")
                    .foregroundStyle(.tertiary)
                Text(
                    reason == .noLocation
                        ? "Set a property location to see weather."
                        : "Weather is unavailable right now."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, CroftTheme.space(2))
            .padding(.horizontal, CroftTheme.space(3))
            .accessibilityLabel("Weather unavailable")
        }
    }

    private func attentionCard(_ feed: TodayFeedStore) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            HStack(alignment: .firstTextBaseline) {
                Text("Needs attention")
                    .font(CroftTheme.heading)
                    .foregroundStyle(Color.domainGarden)
                Spacer()
                Text(feed.itemCount == 1 ? "1 item" : "\(feed.itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
                ForEach(feed.items) { item in
                    attentionRow(item, feed: feed)
                }
            }
        }
        .padding(CroftTheme.space(5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.domainGarden.opacity(0.12),
            in: RoundedRectangle(cornerRadius: CroftTheme.space(3))
        )
    }

    private func attentionRow(_ item: AttentionItem, feed: TodayFeedStore) -> some View {
        HStack(alignment: .top, spacing: CroftTheme.space(3)) {
            Circle()
                .fill(accent(for: item.kind))
                .frame(width: 8, height: 8)
                .padding(.top, CroftTheme.space(1))
            VStack(alignment: .leading, spacing: CroftTheme.space(0.5)) {
                Text(item.kind.label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(accent(for: item.kind))
                Text(item.title)
                    .font(.system(size: 13))
                if let reason = item.reason {
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: CroftTheme.space(2))
            if let taskID = item.taskID {
                Button {
                    feed.complete(taskID: taskID)
                } label: {
                    Image(systemName: "circle")
                        .foregroundStyle(Color.domainGarden)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Complete \(item.title)")
            }
        }
    }

    private func quietBlock(_ feed: TodayFeedStore) -> some View {
        VStack(spacing: CroftTheme.space(3)) {
            Image(systemName: "leaf")
                .font(.title)
                .foregroundStyle(Color.domainGarden)
            Text("The garden is quiet")
                .font(CroftTheme.heading)
                .foregroundStyle(Color.domainGarden)
            Text(quietDetail(feed))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 320)
        .padding(CroftTheme.space(6))
        .frame(maxWidth: .infinity)
        .background(
            Color.domainGarden.opacity(0.07),
            in: RoundedRectangle(cornerRadius: CroftTheme.space(3))
        )
    }

    private func quietDetail(_ feed: TodayFeedStore) -> String {
        let base = "Nothing needs attention today."
        guard let hint = feed.nextWindowHint else {
            return base
        }
        return "\(base) \(hint)"
    }

    private func recentlyCard(_ feed: TodayFeedStore) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            Text("Recently")
                .font(CroftTheme.heading)
            VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
                ForEach(feed.recentLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(CroftTheme.space(5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.surfaceSecondary,
            in: RoundedRectangle(cornerRadius: CroftTheme.space(3))
        )
    }

    private func accent(for kind: AttentionKind) -> Color {
        switch kind {
        case .frostAlert, .overdueTask, .harvestCheck: Color.domainHealth
        case .dueTodayTask, .plantableNow: Color.domainGarden
        case .quietLately: Color.primary.opacity(0.3)
        }
    }
}

private func storedLocation(in database: AppDatabase?) -> GeoLocation? {
    guard let database,
        let location = try? GardenStructureRepository(database).properties().first?.location
    else {
        return nil
    }
    return GeoLocation(latitude: location.latitude, longitude: location.longitude)
}

private struct ForecastPopover: View {
    let model: TodayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            switch model.forecast {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
            case .unavailable:
                Text("The forecast is unavailable.")
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.secondary)
            case .loaded(let days):
                VStack(spacing: CroftTheme.space(2)) {
                    ForEach(days.prefix(7), id: \.date) { day in
                        row(day)
                    }
                }
            }
            attribution
        }
        .padding(CroftTheme.space(4))
        .frame(width: 260)
        .task {
            await model.loadForecast()
        }
    }

    private func row(_ day: DayForecast) -> some View {
        HStack(spacing: CroftTheme.space(2)) {
            Text(day.date, format: .dateTime.weekday(.abbreviated))
                .font(.caption)
                .frame(width: 34, alignment: .leading)
            Image(systemName: day.symbolName)
                .font(.caption)
                .foregroundStyle(Color.domainWater)
                .frame(width: 20)
            Spacer(minLength: CroftTheme.space(1))
            if day.precipitationChance > 0 {
                Text(day.precipitationChance, format: .percent.precision(.fractionLength(0)))
                    .font(.caption2)
                    .foregroundStyle(Color.domainWater)
            }
            Text(day.high, format: .measurement(width: .narrow, usage: .weather))
                .font(.caption)
            Text(day.low, format: .measurement(width: .narrow, usage: .weather))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var attribution: some View {
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
}
