import Foundation
import OpenAPIRuntime

struct RegisteredDevice: Sendable {
    var id: String
    var name: String
}

struct RegisteredAppInfo: Sendable {
    var id: String
    var identifier: String
    var name: String
    var iconHash: String?
}

struct ChimelingAPI: Sendable {
    private let client: any APIProtocol

    init(client: any APIProtocol) {
        self.client = client
    }

    init() {
        self.init(client: makeClient())
    }

    func registerDevice(name: String) async throws -> APIOutcome<RegisteredDevice> {
        let output = try await client.registerDevice(
            .init(body: .json(.init(name: name, platform: .darwin)))
        )
        switch output {
        case .created(let created):
            let json = try created.body.json
            return .success(RegisteredDevice(id: json.id, name: json.name))
        case .unauthorized:
            return .unauthorized
        case .badRequest:
            return .failure(status: 400)
        case .undocumented(let status, _):
            return .from(statusCode: status)
        }
    }

    func updateDevice(id: String, name: String) async throws -> APIOutcome<RegisteredDevice> {
        let output = try await client.updateDevice(
            .init(path: .init(deviceId: id), body: .json(.init(name: name)))
        )
        switch output {
        case .ok(let ok):
            let json = try ok.body.json
            return .success(RegisteredDevice(id: json.id, name: json.name))
        case .unauthorized, .forbidden:
            return .unauthorized
        case .notFound:
            return .notFound
        case .badRequest:
            return .failure(status: 400)
        case .undocumented(let status, _):
            return .from(statusCode: status)
        }
    }

    func listApps(deviceID: String) async throws -> APIOutcome<[RegisteredAppInfo]> {
        let output = try await client.listApps(.init(path: .init(deviceId: deviceID)))
        switch output {
        case .ok(let ok):
            let json = try ok.body.json
            return .success(json.map { app in
                RegisteredAppInfo(
                    id: app.id,
                    identifier: app.identifier,
                    name: app.name,
                    iconHash: app.iconHash
                )
            })
        case .unauthorized, .forbidden:
            return .unauthorized
        case .notFound:
            return .notFound
        case .undocumented(let status, _):
            return .from(statusCode: status)
        }
    }

    func registerApp(
        deviceID: String,
        identifier: String,
        name: String,
        iconHash: String?
    ) async throws -> APIOutcome<RegisteredAppInfo> {
        let output = try await client.registerApp(
            .init(
                path: .init(deviceId: deviceID),
                body: .json(.init(name: name, identifier: identifier, iconHash: iconHash))
            )
        )
        switch output {
        case .created(let created):
            let json = try created.body.json
            return .success(
                RegisteredAppInfo(
                    id: json.id,
                    identifier: json.identifier,
                    name: json.name,
                    iconHash: json.iconHash
                )
            )
        case .unauthorized, .forbidden:
            return .unauthorized
        case .notFound:
            return .notFound
        case .unprocessableContent:
            return .unprocessable
        case .badRequest:
            return .failure(status: 400)
        case .undocumented(let status, _):
            return .from(statusCode: status)
        }
    }

    func updateApp(
        deviceID: String,
        appID: String,
        name: String,
        iconHash: String?
    ) async throws -> APIOutcome<RegisteredAppInfo> {
        let output = try await client.updateApp(
            .init(
                path: .init(deviceId: deviceID, appId: appID),
                body: .json(.init(name: name, iconHash: iconHash))
            )
        )
        switch output {
        case .ok(let ok):
            let json = try ok.body.json
            return .success(
                RegisteredAppInfo(
                    id: json.id,
                    identifier: json.identifier,
                    name: json.name,
                    iconHash: json.iconHash
                )
            )
        case .unauthorized, .forbidden:
            return .unauthorized
        case .notFound:
            return .notFound
        case .unprocessableContent:
            return .unprocessable
        case .badRequest:
            return .failure(status: 400)
        case .undocumented(let status, _):
            return .from(statusCode: status)
        }
    }

    func checkIconExistence(hash: String) async throws -> APIOutcome<Void> {
        let output = try await client.checkIconExistence(.init(path: .init(hash: hash)))
        switch output {
        case .ok:
            return .ok
        case .notFound:
            return .notFound
        case .undocumented(let status, _):
            return .from(statusCode: status)
        }
    }

    func registerIcon(png: Data) async throws -> APIOutcome<String> {
        let output = try await client.registerIcon(.init(body: .png(HTTPBody(png))))
        switch output {
        case .created(let created):
            let json = try created.body.json
            return .success(json.hash)
        case .conflict:
            return .conflict
        case .unauthorized:
            return .unauthorized
        case .contentTooLarge, .unsupportedMediaType:
            return .unprocessable
        case .undocumented(let status, _):
            return .from(statusCode: status)
        }
    }

    func reportPresence(
        deviceID: String,
        status: PresenceStatus,
        activity: ReportableActivity?
    ) async throws -> APIOutcome<Void> {
        let payloadStatus: Operations.ReportDevicePresence.Input.Body.JsonPayload.StatusPayload =
            switch status {
            case .online: .online
            case .idle: .idle
            case .offline: .online
            }
        let payloadActivity = activity.map {
            Operations.ReportDevicePresence.Input.Body.JsonPayload.ActivityPayload(
                appId: $0.appID,
                startedAt: $0.startedAt
            )
        }
        let output = try await client.reportDevicePresence(
            .init(
                path: .init(deviceId: deviceID),
                body: .json(.init(status: payloadStatus, activity: payloadActivity))
            )
        )
        switch output {
        case .noContent:
            return .ok
        case .unauthorized, .forbidden:
            return .unauthorized
        case .notFound:
            return .notFound
        case .unprocessableContent:
            return .unprocessable
        case .badRequest:
            return .failure(status: 400)
        case .undocumented(let status, _):
            return .from(statusCode: status)
        }
    }

    func clearPresence(deviceID: String) async throws -> APIOutcome<Void> {
        let output = try await client.clearDevicePresence(.init(path: .init(deviceId: deviceID)))
        switch output {
        case .noContent:
            return .ok
        case .unauthorized, .forbidden:
            return .unauthorized
        case .notFound:
            return .notFound
        case .badRequest:
            return .failure(status: 400)
        case .undocumented(let status, _):
            return .from(statusCode: status)
        }
    }
}
