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
        let token = try await tokenProvider(false)
        guard let token, !token.isEmpty else {
            return Self.missingToken()
        }
        var request = request
        request.headerFields[.authorization] = "Bearer \(token)"
        return try await next(request, body, baseURL)
    }

    private static func missingToken() -> (HTTPResponse, HTTPBody?) {
        var response = HTTPResponse(status: .unauthorized)
        response.headerFields[.contentType] = "text/plain"
        return (response, HTTPBody("Unauthorized: missing session token"))
    }
}
