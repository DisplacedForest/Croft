import Foundation
import Testing

@testable import Domain

@Test func aFastOperationReturnsItsValue() async throws {
    let value = try await withDeadline(.seconds(5)) {
        42
    }
    #expect(value == 42)
}

@Test func aStalledOperationThrowsDeadlineExceeded() async {
    await #expect(throws: DeadlineExceeded()) {
        try await withDeadline(.milliseconds(50)) {
            try await Task.sleep(for: .seconds(3600))
        }
    }
}

@Test func anOperationErrorPropagatesUnchanged() async {
    struct Boom: Error, Equatable {}
    await #expect(throws: Boom()) {
        try await withDeadline(.seconds(5)) {
            throw Boom()
        }
    }
}

@Test func theLosingOperationObservesCancellation() async throws {
    let cancelled = Flag()
    _ = try? await withDeadline(.milliseconds(50)) {
        do {
            try await Task.sleep(for: .seconds(3600))
        } catch is CancellationError {
            await cancelled.raise()
            throw CancellationError()
        }
    }
    for _ in 0..<100 {
        if await cancelled.isRaised {
            break
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(await cancelled.isRaised)
}

private actor Flag {
    private(set) var isRaised = false

    func raise() {
        isRaised = true
    }
}
