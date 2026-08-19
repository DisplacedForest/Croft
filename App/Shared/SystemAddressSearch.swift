import Foundation
import GardenModel
import MapKit

import struct Domain.GeoCoordinate

enum AddressSearchFailure: Error {
    case noMatch
    case unusableCoordinate
}

struct SystemAddressSearch: AddressSearching {
    func suggestions(for query: String) async -> [AddressSuggestion] {
        await AddressCompleterSession.shared.suggestions(for: query)
    }

    func resolve(_ suggestion: AddressSuggestion) async throws -> ResolvedPlace {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = Self.searchQuery(for: suggestion)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            throw AddressSearchFailure.noMatch
        }
        let placemark = item.placemark
        guard
            let coordinate = GeoCoordinate(
                latitude: placemark.coordinate.latitude,
                longitude: placemark.coordinate.longitude
            )
        else {
            throw AddressSearchFailure.unusableCoordinate
        }
        return ResolvedPlace(
            name: Self.name(for: item, fallback: suggestion),
            coordinate: coordinate
        )
    }

    private static func searchQuery(for suggestion: AddressSuggestion) -> String {
        let parts = [suggestion.title, suggestion.subtitle]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    static let reverseGeocode: ReverseGeocode = { coordinate in
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            throw AddressSearchFailure.noMatch
        }
        var parts: [String] = []
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        if !street.isEmpty {
            parts.append(street)
        } else if let name = placemark.name, !name.isEmpty {
            parts.append(name)
        }
        if let locality = placemark.locality, !parts.contains(locality) {
            parts.append(locality)
        }
        if let area = placemark.administrativeArea, !parts.contains(area) {
            parts.append(area)
        }
        guard !parts.isEmpty else {
            throw AddressSearchFailure.noMatch
        }
        return ResolvedPlace(name: parts.joined(separator: ", "), coordinate: coordinate)
    }

    private static func name(for item: MKMapItem, fallback: AddressSuggestion) -> String {
        let placemark = item.placemark
        var parts: [String] = []
        if let name = item.name, !name.isEmpty {
            parts.append(name)
        }
        if let locality = placemark.locality, !parts.contains(locality) {
            parts.append(locality)
        }
        if let area = placemark.administrativeArea, !parts.contains(area) {
            parts.append(area)
        }
        if parts.isEmpty {
            return searchQuery(for: fallback)
        }
        return parts.joined(separator: ", ")
    }
}

@MainActor
private final class AddressCompleterSession: NSObject, MKLocalSearchCompleterDelegate {
    static let shared = AddressCompleterSession()

    private let completer = MKLocalSearchCompleter()
    private var pending: (id: Int, continuation: CheckedContinuation<[AddressSuggestion], Never>)?
    private var nextID = 0

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func suggestions(for query: String) async -> [AddressSuggestion] {
        finish(with: [])
        guard completer.queryFragment != query else {
            return Self.map(completer.results)
        }
        nextID += 1
        let id = nextID
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                pending = (id, continuation)
                completer.queryFragment = query
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancel(id)
            }
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated {
            finish(with: Self.map(self.completer.results))
        }
    }

    nonisolated func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: any Error
    ) {
        MainActor.assumeIsolated {
            finish(with: [])
        }
    }

    private func cancel(_ id: Int) {
        guard pending?.id == id else {
            return
        }
        finish(with: [])
    }

    private func finish(with suggestions: [AddressSuggestion]) {
        guard let pending else {
            return
        }
        self.pending = nil
        pending.continuation.resume(returning: suggestions)
    }

    private static func map(_ results: [MKLocalSearchCompletion]) -> [AddressSuggestion] {
        results.map { completion in
            AddressSuggestion(
                id: completion.title + "|" + completion.subtitle,
                title: completion.title,
                subtitle: completion.subtitle
            )
        }
    }
}
