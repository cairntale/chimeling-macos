import ClerkKit
import Foundation
import OpenAPIURLSession

func makeClient() -> Client {
    #if DEBUG
    let serverURL = URL(string: "http://localhost:3000")!
    #else
    let serverURL = URL(string: "https://chimeling.app")!
    #endif
    return Client(
        serverURL: serverURL,
        transport: URLSessionTransport(),
        middlewares: [
            AuthenticationMiddleware { try await Clerk.shared.auth.getToken() }
        ]
    )
}
