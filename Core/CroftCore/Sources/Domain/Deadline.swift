public struct DeadlineExceeded: Error, Equatable {
    public init() {}
}

public func withDeadline<T: Sendable>(
    _ limit: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: limit)
            throw DeadlineExceeded()
        }
        guard let first = try await group.next() else {
            throw DeadlineExceeded()
        }
        group.cancelAll()
        return first
    }
}
