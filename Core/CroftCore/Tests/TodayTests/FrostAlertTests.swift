import Foundation
import Testing
import Today

import enum Domain.FrostTolerance

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

private func forecastDay(_ date: Date, lowCelsius: Double) -> DayForecast {
    DayForecast(
        date: date,
        symbolName: "cloud",
        high: Measurement(value: lowCelsius + 10, unit: .celsius),
        low: Measurement(value: lowCelsius, unit: .celsius),
        precipitationChance: 0
    )
}

private func candidate(
    _ id: String,
    _ name: String,
    location: String? = nil,
    tolerance: FrostTolerance? = nil
) -> AttentionProviders.FrostRiskCandidate {
    AttentionProviders.FrostRiskCandidate(
        plantingID: id, plantName: name, locationName: location, frostTolerance: tolerance)
}

private let octoberNoon = day(2026, 10, 8)

struct FrostAlertProviderTests {
    @Test func aFreezingNightNamesTheTenderPlantings() throws {
        let items = AttentionProviders.frostAlerts(
            forecast: [forecastDay(day(2026, 10, 8), lowCelsius: -1)],
            candidates: [
                candidate("p1", "Brandywine tomato", location: "Bed 3", tolerance: .tender),
                candidate("p2", "Basil", location: "Long Bed", tolerance: .tender),
                candidate("p3", "Kale", location: "Bed 2", tolerance: .hardy),
            ],
            now: octoberNoon, calendar: calendar)
        #expect(items.count == 1)
        #expect(items[0].kind == .frostAlert)
        #expect(items[0].title == "Brandywine tomato (Bed 3) and Basil (Long Bed)")
        #expect(items[0].reason == "Low of 30\u{00B0} tonight")
    }

    @Test func aHardyOnlyGardenStaysSilent() throws {
        let items = AttentionProviders.frostAlerts(
            forecast: [forecastDay(day(2026, 10, 8), lowCelsius: -4)],
            candidates: [
                candidate("p1", "Kale", tolerance: .hardy),
                candidate("p2", "Garlic", tolerance: .hardy),
            ],
            now: octoberNoon, calendar: calendar)
        #expect(items.isEmpty)
    }

    @Test func missingToleranceIsNeverGuessed() throws {
        let items = AttentionProviders.frostAlerts(
            forecast: [forecastDay(day(2026, 10, 8), lowCelsius: -4)],
            candidates: [candidate("p1", "Mystery plant")],
            now: octoberNoon, calendar: calendar)
        #expect(items.isEmpty)
    }

    @Test func thresholdsFollowTolerance() throws {
        let nearFreezing = AttentionProviders.frostAlerts(
            forecast: [forecastDay(day(2026, 10, 8), lowCelsius: 2)],
            candidates: [
                candidate("p1", "Basil", tolerance: .tender),
                candidate("p2", "Lettuce", tolerance: .halfHardy),
            ],
            now: octoberNoon, calendar: calendar)
        #expect(nearFreezing.count == 1)
        #expect(nearFreezing[0].title == "Basil")

        let atFreezing = AttentionProviders.frostAlerts(
            forecast: [forecastDay(day(2026, 10, 8), lowCelsius: 0)],
            candidates: [
                candidate("p1", "Basil", tolerance: .tender),
                candidate("p2", "Lettuce", tolerance: .halfHardy),
            ],
            now: octoberNoon, calendar: calendar)
        #expect(atFreezing.count == 1)
        #expect(atFreezing[0].title == "Basil and Lettuce")

        let mild = AttentionProviders.frostAlerts(
            forecast: [forecastDay(day(2026, 10, 8), lowCelsius: 2.1)],
            candidates: [candidate("p1", "Basil", tolerance: .tender)],
            now: octoberNoon, calendar: calendar)
        #expect(mild.isEmpty)
    }

    @Test func twoColdNightsMakeTwoItemsAndFarNightsAreIgnored() throws {
        let items = AttentionProviders.frostAlerts(
            forecast: [
                forecastDay(day(2026, 10, 8), lowCelsius: -1),
                forecastDay(day(2026, 10, 9), lowCelsius: -2),
                forecastDay(day(2026, 10, 11), lowCelsius: -5),
            ],
            candidates: [candidate("p1", "Basil", tolerance: .tender)],
            now: octoberNoon, calendar: calendar)
        #expect(items.count == 2)
        #expect(items[0].reason == "Low of 30\u{00B0} tonight")
        #expect(items[1].reason == "Low of 28\u{00B0} Friday night")
    }

    @Test func anEmptyForecastOrGardenIsSilence() throws {
        #expect(
            AttentionProviders.frostAlerts(
                forecast: [], candidates: [candidate("p1", "Basil", tolerance: .tender)],
                now: octoberNoon, calendar: calendar
            ).isEmpty)
        #expect(
            AttentionProviders.frostAlerts(
                forecast: [forecastDay(day(2026, 10, 8), lowCelsius: -1)], candidates: [],
                now: octoberNoon, calendar: calendar
            ).isEmpty)
    }
}

struct FrostAlertFeedTests {
    @Test func frostOutranksEverythingAndRespectsTheCap() throws {
        var items = AttentionProviders.frostAlerts(
            forecast: [forecastDay(day(2026, 10, 8), lowCelsius: -1)],
            candidates: [candidate("p1", "Basil", tolerance: .tender)],
            now: octoberNoon, calendar: calendar)
        for index in 0..<9 {
            items.append(
                AttentionItem(
                    id: "over-\(index)", kind: .overdueTask, title: "Overdue \(index)",
                    orderDate: day(2026, 10, 1 + index)))
        }
        let composed = AttentionFeed.compose(items)
        #expect(composed.count == 6)
        #expect(composed[0].kind == .frostAlert)
        #expect(composed.filter { $0.kind == .overdueTask }.count == 5)
        #expect(composed.count <= AttentionLimits.totalCap)
    }
}
