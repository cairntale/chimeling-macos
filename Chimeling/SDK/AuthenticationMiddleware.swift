import Foundation
import HTTPTypes
import OpenAPIRuntime

struct AuthenticationMiddleware: Sendable {
    let tokenProvider: @Sendable (_ skipCache: Bool) async throws -> String?
}

extension AuthenticationMiddleware: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        if let token = try await tokenProvider(false) {
            request.headerFields[.authorization] = "Bearer \(token)"
        }
        let (response, responseBody) = try await next(request, body, baseURL)
        guard response.status == .unauthorized else {
            return (response, responseBody)
        }
        guard body.map(\.iterationBehavior) != .single else {
            return (response, responseBody)
        }
        let fresh: String?
        do {
            fresh = try await tokenProvider(true)
        } catch {
            return (response, responseBody)
        }
        guard let fresh else {
            return (response, responseBody)
        }
        request.headerFields[.authorization] = "Bearer \(fresh)"
        return try await next(request, body, baseURL)
    }
}
