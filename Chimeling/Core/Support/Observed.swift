import Observation

enum Observed {
    static func values<Value: Equatable & Sendable>(
        of extract: @escaping @MainActor () -> Value
    ) -> AsyncStream<Value> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                var last: Value?
                while !Task.isCancelled {
                    await withCheckedContinuation { (resume: CheckedContinuation<Void, Never>) in
                        let value = withObservationTracking {
                            extract()
                        } onChange: {
                            resume.resume()
                        }
                        if last != value {
                            last = value
                            continuation.yield(value)
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
