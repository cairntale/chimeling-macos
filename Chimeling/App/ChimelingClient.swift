import ClerkKit
import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

func makeClient() -> Client {
    Client(
        serverURL: ChimelingEnvironment.current.serverURL,
        configuration: Configuration(dateTranscoder: ISO8601()),
        transport: URLSessionTransport(),
        middlewares: [
            AuthenticationMiddleware { try await Clerk.shared.auth.getToken() }
        ]
    )
}
