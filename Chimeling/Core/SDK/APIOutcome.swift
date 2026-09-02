enum APIOutcome<Value: Sendable>: Sendable {
    case success(Value)
    case unauthorized
    case notFound
    case conflict
    case unprocessable
    case failure(status: Int)

    static func from(statusCode: Int) -> Self {
        switch statusCode {
        case 401, 403:
            .unauthorized
        case 404:
            .notFound
        case 409:
            .conflict
        case 413, 415, 422:
            .unprocessable
        default:
            .failure(status: statusCode)
        }
    }
}

extension APIOutcome where Value == Void {
    static var ok: Self { .success(()) }
}
