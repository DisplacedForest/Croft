import Foundation
import Testing
import Today

import struct Domain.GardenTask

private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int, hour: Int = 12) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = dayOfMonth
    components.hour = hour
    return calendar.date(from: components)!
}

private func task(_ title: String, due: Date?) -> GardenTask {
    GardenTask(type: .water, title: title, dueOn: due)
}

private let juneNoon = day(2026, 6, 18)

struct TaskProviderTests {
    @Test func overdueAndTodaySplitAtStartOfDay() throws {
        let items = AttentionProviders.taskItems(
            openTasks: [
                task("Water the propagation trays", due: day(2026, 6, 16)),
                task("Net the brassica bed", due: day(2026, 6, 17)),
                task("Feed the tomatoes", due: day(2026, 6, 18, hour: 8)),
                task("Undated", due: nil),
                task("Future", due: day(2026, 6, 20)),
            ],
            now: juneNoon, calendar: calendar)
        #expect(items.map(\.kind) == [.overdueTask, .overdueTask, .dueTodayTask])
        #expect(items[0].reason == "Due Jun 16, 2 days ago")
        #expect(items[1].reason == "Due Jun 17, yesterday")
        #expect(items[2].reason == nil)
        #expect(items.allSatisfy { $0.taskID != nil })
    }
}

struct HarvestCheckProviderTests {
    @Test func pastMaturityWithNoHarvestGetsAnItem() throws {
        let items = AttentionProviders.harvestChecks(
            candidates: [
                AttentionProviders.HarvestCandidate(
                    plantingID: "p1", plantName: "Brandywine tomato",
                    locationName: "Bed 3",
                    plantedOn: day(2026, 2, 1),
                    daysToMaturity: 100...120)
            ],
            now: juneNoon, calendar: calendar)
        #expect(items.count == 1)
        #expect(items[0].title == "Brandywine tomato, Bed 3")
        #expect(items[0].reason == "17 days past expected maturity, no harvest recorded")
    }

    @Test func aRecordedHarvestSilencesTheCheck() throws {
        let items = AttentionProviders.harvestChecks(
            candidates: [
                AttentionProviders.HarvestCandidate(
                    plantingID: "p1", plantName: "Brandywine tomato",
                    plantedOn: day(2026, 2, 1),
                    daysToMaturity: 100...120,
                    firstHarvestOn: day(2026, 6, 10))
            ],
            now: juneNoon, calendar: calendar)
        #expect(items.isEmpty)
    }

    @Test func transplantBasisStartsTheClockAtTransplant() throws {
        let items = AttentionProviders.harvestChecks(
            candidates: [
                AttentionProviders.HarvestCandidate(
                    plantingID: "p1", plantName: "Tomato",
                    plantedOn: day(2026, 2, 1),
                    transplantedOn: day(2026, 5, 1),
                    daysToMaturity: 100...120,
                    basis: .fromTransplant)
            ],
            now: juneNoon, calendar: calendar)
        #expect(items.isEmpty)
    }

    @Test func aStoredExpectedMaturityWins() throws {
        let items = AttentionProviders.harvestChecks(
            candidates: [
                AttentionProviders.HarvestCandidate(
                    plantingID: "p1", plantName: "Tomato",
                    plantedOn: day(2026, 6, 1),
                    expectedMaturityOn: day(2026, 6, 10),
                    daysToMaturity: 100...120)
            ],
            now: juneNoon, calendar: calendar)
        #expect(items.count == 1)
        #expect(items[0].reason == "8 days past expected maturity, no harvest recorded")
    }

    @Test func missingDatesOrMaturityStayQuiet() throws {
        let items = AttentionProviders.harvestChecks(
            candidates: [
                AttentionProviders.HarvestCandidate(
                    plantingID: "p1", plantName: "No maturity",
                    plantedOn: day(2026, 2, 1)),
                AttentionProviders.HarvestCandidate(
                    plantingID: "p2", plantName: "No dates",
                    daysToMaturity: 50...60),
            ],
            now: juneNoon, calendar: calendar)
        #expect(items.isEmpty)
    }
}

struct PlantableProviderTests {
    @Test func groupsBecomeAggregateLines() throws {
        let items = AttentionProviders.plantableItems(
            groups: [
                AttentionProviders.PlantableGroup(
                    action: .directSow,
                    plantNames: ["spinach", "arugula", "cilantro"],
                    windowEnd: day(2026, 8, 20),
                    firstFrost: day(2026, 10, 12))
            ],
            now: day(2026, 8, 18), calendar: calendar)
        #expect(items.count == 1)
        #expect(items[0].title == "Direct sow spinach, arugula, and cilantro")
        #expect(items[0].reason == "7 weeks to first frost, Oct 12")
    }

    @Test func manyNamesTruncateWithACount() throws {
        let items = AttentionProviders.plantableItems(
            groups: [
                AttentionProviders.PlantableGroup(
                    action: .sowIndoors,
                    plantNames: ["a", "b", "c", "d", "e"],
                    windowEnd: day(2026, 3, 20))
            ],
            now: day(2026, 3, 1), calendar: calendar)
        #expect(items[0].title == "Start indoors a, b, and c, and 2 more")
        #expect(items[0].reason == "Window closes Mar 20")
    }
}

struct QuietProviderTests {
    @Test func staleObservationsSurfaceAndFreshOnesStayQuiet() throws {
        let items = AttentionProviders.quietItems(
            candidates: [
                AttentionProviders.QuietCandidate(
                    plantingID: "p1", plantName: "Butternut squash",
                    locationName: "north bed",
                    lastObservedOn: day(2026, 6, 2)),
                AttentionProviders.QuietCandidate(
                    plantingID: "p2", plantName: "Fresh",
                    lastObservedOn: day(2026, 6, 10)),
                AttentionProviders.QuietCandidate(
                    plantingID: "p3", plantName: "Never observed",
                    plantedOn: day(2026, 5, 1)),
                AttentionProviders.QuietCandidate(
                    plantingID: "p4", plantName: "No anchor"),
            ],
            now: juneNoon, calendar: calendar)
        #expect(items.map(\.id) == ["quiet-p1", "quiet-p3"])
        #expect(items[0].title == "Butternut squash, north bed")
        #expect(items[0].reason == "No observation in 16 days")
    }
}

struct RecentLineTests {
    @Test func linesFormatWithDayPhrasesNewestFirst() throws {
        let lines = AttentionProviders.recentLines(
            events: [
                AttentionProviders.RecentEvent(
                    date: day(2026, 6, 14), text: "first flower on the Delicata squash."),
                AttentionProviders.RecentEvent(
                    date: day(2026, 6, 17), text: "harvested 940 g of Sungold tomatoes."),
                AttentionProviders.RecentEvent(
                    date: day(2026, 6, 1), text: "too old to show."),
            ],
            now: juneNoon, calendar: calendar)
        #expect(
            lines == [
                "Yesterday: harvested 940 g of Sungold tomatoes.",
                "Sunday: first flower on the Delicata squash.",
            ])
    }

    @Test func linesCapAtFive() throws {
        let events = (10...16).map {
            AttentionProviders.RecentEvent(date: day(2026, 6, $0), text: "event \($0).")
        }
        let lines = AttentionProviders.recentLines(
            events: events, now: juneNoon, calendar: calendar)
        #expect(lines.count == AttentionLimits.recentlyLineCap)
        #expect(lines.first == "Tuesday: event 16.")
    }
}

struct FeedComposeTests {
    private func denseItems() -> [AttentionItem] {
        var items: [AttentionItem] = []
        for index in 0..<7 {
            items.append(
                AttentionItem(
                    id: "over-\(index)", kind: .overdueTask, title: "Overdue \(index)",
                    orderDate: day(2026, 6, 1 + index)))
        }
        for index in 0..<5 {
            items.append(
                AttentionItem(
                    id: "today-\(index)", kind: .dueTodayTask, title: "Today \(index)",
                    orderDate: day(2026, 6, 18, hour: 8 + index)))
        }
        for index in 0..<4 {
            items.append(
                AttentionItem(
                    id: "harvest-\(index)", kind: .harvestCheck, title: "Harvest \(index)",
                    orderDate: day(2026, 6, 1 + index)))
        }
        items.append(
            AttentionItem(
                id: "plantable-direct", kind: .plantableNow, title: "Direct sow things",
                orderDate: day(2026, 8, 1)))
        for index in 0..<3 {
            items.append(
                AttentionItem(
                    id: "quiet-\(index)", kind: .quietLately, title: "Quiet \(index)",
                    orderDate: day(2026, 5, 1 + index)))
        }
        return items
    }

    @Test func aDenseJuneRespectsQuotasAndTheCap() throws {
        let composed = AttentionFeed.compose(denseItems())
        #expect(composed.count == AttentionLimits.totalCap)
        #expect(composed.filter { $0.kind == .overdueTask }.count == 5)
        #expect(composed.filter { $0.kind == .dueTodayTask }.count == 3)
        #expect(composed.filter { $0.kind == .harvestCheck }.isEmpty)
        #expect(composed.prefix(5).allSatisfy { $0.kind == .overdueTask })
    }

    @Test func theFeedIsDeterministic() throws {
        let once = AttentionFeed.compose(denseItems())
        let twice = AttentionFeed.compose(denseItems().shuffled())
        #expect(once == twice)
    }

    @Test func aSparseSeasonKeepsEverythingInRankOrder() throws {
        let items = [
            AttentionItem(
                id: "quiet-1", kind: .quietLately, title: "Quiet",
                orderDate: day(2026, 6, 1)),
            AttentionItem(
                id: "today-1", kind: .dueTodayTask, title: "Feed the tomatoes",
                orderDate: day(2026, 6, 18)),
            AttentionItem(
                id: "plantable-direct", kind: .plantableNow, title: "Direct sow spinach",
                orderDate: day(2026, 8, 1)),
        ]
        let composed = AttentionFeed.compose(items.shuffled())
        #expect(composed.map(\.kind) == [.dueTodayTask, .plantableNow, .quietLately])
    }

    @Test func aJanuaryEmptyFixtureComposesToNothing() throws {
        #expect(AttentionFeed.compose([]).isEmpty)
        let tasks = AttentionProviders.taskItems(
            openTasks: [], now: day(2026, 1, 10), calendar: calendar)
        let harvests = AttentionProviders.harvestChecks(
            candidates: [], now: day(2026, 1, 10), calendar: calendar)
        #expect(AttentionFeed.compose(tasks + harvests).isEmpty)
    }
}

private struct StubForecast: ForecastProviding {
    let result: Result<[DayForecast], Error>
    func dailyForecast(at location: GeoLocation) async throws -> [DayForecast] {
        try result.get()
    }
}

private struct StubLocation: LocationProviding {
    func currentLocation() async throws -> GeoLocation {
        GeoLocation(latitude: 44.5, longitude: -72.8)
    }
}

private struct UnreachableError: Error {}

private struct FailingWeather: WeatherProviding {
    func currentWeather(at location: GeoLocation) async throws -> WeatherSnapshot {
        throw UnreachableError()
    }

    func todaySummary(at location: GeoLocation) async throws -> DailyWeatherSummary {
        throw UnreachableError()
    }
}

struct ForecastStateTests {
    private func forecastDays() -> [DayForecast] {
        [
            DayForecast(
                date: day(2026, 6, 18), symbolName: "sun.max",
                high: Measurement(value: 25, unit: .celsius),
                low: Measurement(value: 12, unit: .celsius),
                precipitationChance: 0.1)
        ]
    }

    @Test @MainActor func loadedForecastCachesForTheDay() async throws {
        let days = forecastDays()
        let counting = CountingForecast(days: days)
        let model = TodayViewModel(
            weatherProvider: FailingWeather(),
            locationProvider: StubLocation(),
            forecastProvider: counting,
            calendar: calendar
        )
        await model.loadForecast(on: juneNoon)
        #expect(model.forecast == .loaded(days))
        await model.loadForecast(on: day(2026, 6, 18, hour: 20))
        #expect(counting.count == 1)
        await model.loadForecast(on: day(2026, 6, 19))
        #expect(counting.count == 2)
    }

    @Test @MainActor func failureIsUnavailableAndRecoverable() async throws {
        struct Boom: Error {}
        let model = TodayViewModel(
            weatherProvider: FailingWeather(),
            locationProvider: StubLocation(),
            forecastProvider: StubForecast(result: .failure(Boom())),
            calendar: calendar
        )
        await model.loadForecast(on: juneNoon)
        #expect(model.forecast == .unavailable)
    }

    @Test @MainActor func noProviderMeansUnavailable() async throws {
        let model = TodayViewModel(
            weatherProvider: FailingWeather(),
            locationProvider: StubLocation(),
            calendar: calendar
        )
        await model.loadForecast(on: juneNoon)
        #expect(model.forecast == .unavailable)
    }

    @Test @MainActor func anEmptyForecastIsUnavailableNotGuessed() async throws {
        let model = TodayViewModel(
            weatherProvider: FailingWeather(),
            locationProvider: StubLocation(),
            forecastProvider: StubForecast(result: .success([])),
            calendar: calendar
        )
        await model.loadForecast(on: juneNoon)
        #expect(model.forecast == .unavailable)
    }
}

private final class CountingForecast: ForecastProviding, @unchecked Sendable {
    let days: [DayForecast]
    private let lock = NSLock()
    private var served = 0

    var count: Int {
        lock.withLock { served }
    }

    init(days: [DayForecast]) {
        self.days = days
    }

    func dailyForecast(at location: GeoLocation) async throws -> [DayForecast] {
        lock.withLock { served += 1 }
        return days
    }
}
