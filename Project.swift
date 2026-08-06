import ProjectDescription

let project = Project(
  name: "Chimeling",
  targets: [
    .target(
      name: "Chimeling",
      destinations: .macOS,
      product: .app,
      bundleId: "com.cairntale.Chimeling",
      deploymentTargets: .macOS("15.0"),
      infoPlist: .extendingDefault(with: ["LSUIElement": true]),
      buildableFolders: ["Sources", "Resources"],
      dependencies: [],
      settings: .settings(
        base: [
          "DEVELOPMENT_TEAM": "$(CHIMELING_DEVELOPMENT_TEAM)",
        ],
        configurations: [
          .debug(name: "Debug", xcconfig: "Configurations/Debug.xcconfig"),
          .release(name: "Release", xcconfig: "Configurations/Release.xcconfig"),
        ],
      ),
    ),
  ],
)
