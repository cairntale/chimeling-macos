import ProjectDescription

let project = Project(
    name: "Chimeling",
    targets: [
        .target(
            name: "Chimeling",
            destinations: .macOS,
            product: .app,
            bundleId: "com.cairntale.Chimeling",
            infoPlist: .default,
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: []
        ),
    ]
)
