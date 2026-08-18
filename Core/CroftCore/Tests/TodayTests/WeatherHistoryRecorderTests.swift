import Domain
import Foundation
import Testing

@testable import Today

private enum RecorderFailure: Error {
    case fetchFailed
    case writeFailed
}

private struct SummaryProvider: WeatherProviding {
    let result: Result<DailyWeatherSummary, Error>

    func currentWeather(at location: GeoLocation) async throws -> WeatherSnapshot {
        Issue.record("the recorder never asks for current weather")
        throw RecorderFailure.fetchFailed
    }

    func todaySummary(at location: GeoLocation) async throws -> DailyWeatherSummary {
        try result.get()
    }
}

private struct UnreachableSummaryProvider: WeatherProviding {
    func currentWeather(at location: GeoLocation) async throws -> WeatherSnapshot {
        Issue.record("an unlocated property must not trigger a fetch")
        throw RecorderFailure.fetchFailed
    }

    func todaySummary(at location: GeoLocation) async throws -> DailyWeatherSummary {
        Issue.record("an unlocated property must not trigger a fetch")
        throw RecorderFailure.fetchFailed
    }
}

private final class SpyStore: DailyWeatherWriting, @unchecked Sendable {
    var upserts: [DailyWeather] = []
    var failing = false

    func upsert(_ record: DailyWeather) throws {
        if failing {
            throw RecorderFailure.writeFailed
        }
        upserts.append(record)
    }
}

private let summary = DailyWeatherSummary(
    highCelsius: 24.5, lowCelsius: 11.0, precipitationMillimeters: 3.2)

private func property(located: Bool) -> Property {
    Property(
        name: "Home",
        location: located ? GeoCoordinate(latitude: 45.5, longitude: -122.6) : nil
    )
}

@Test func aLocatedPropertyRecordsTodayAsObserved() async throws {
    let store = SpyStore()
    let recorder = WeatherHistoryRecorder(
        provider: SummaryProvider(result: .success(summary)), store: store)
    let now = Date(timeIntervalSince1970: 1_720_000_000)
    await recorder.recordToday(for: property(located: true), now: now)
    let written = try #require(store.upserts.first)
    #expect(store.upserts.count == 1)
    #expect(written.day == DayStamp(now))
    #expect(written.highCelsius == 24.5)
    #expect(written.lowCelsius == 11.0)
    #expect(written.precipitationMillimeters == 3.2)
    #expect(written.provenance == .observed)
}

@Test func anUnlocatedPropertyWritesNothingAndFetchesNothing() async {
    let store = SpyStore()
    let recorder = WeatherHistoryRecorder(provider: UnreachableSummaryProvider(), store: store)
    await recorder.recordToday(for: property(located: false))
    #expect(store.upserts.isEmpty)
}

@Test func aProviderFailureWritesNothing() async {
    let store = SpyStore()
    let recorder = WeatherHistoryRecorder(
        provider: SummaryProvider(result: .failure(RecorderFailure.fetchFailed)), store: store)
    await recorder.recordToday(for: property(located: true))
    #expect(store.upserts.isEmpty)
}

@Test func aWriteFailureIsSwallowed() async {
    let store = SpyStore()
    store.failing = true
    let recorder = WeatherHistoryRecorder(
        provider: SummaryProvider(result: .success(summary)), store: store)
    await recorder.recordToday(for: property(located: true))
    #expect(store.upserts.isEmpty)
}
