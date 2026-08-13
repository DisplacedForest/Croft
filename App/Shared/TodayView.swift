import Design
import SwiftUI
import Today

struct TodayView: View {
    @State private var model = TodayViewModel(
        weatherProvider: SystemWeatherProvider(),
        locationProvider: SystemLocationProvider()
    )

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
        .background(Color.surfacePrimary)
        .task {
            await model.loadWeather()
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
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            Text("In the garden")
                .font(CroftTheme.heading)
                .foregroundStyle(Color.domainGarden)
            Text("Today's garden tasks will appear here as they take root.")
                .font(CroftTheme.supporting)
                .foregroundStyle(.secondary)
        }
        .padding(CroftTheme.space(5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.domainGarden.opacity(0.12),
            in: RoundedRectangle(cornerRadius: CroftTheme.space(3))
        )
    }
}
