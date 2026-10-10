// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "MacUsageTracker",
  platforms: [.macOS(.v13)],
  products: [.executable(name: "MacUsageTracker", targets: ["MacUsageTracker"])],
  targets: [
    .target(name: "UsageCore"),
    .executableTarget(name: "MacUsageTracker", dependencies: ["UsageCore"]),
    .testTarget(name: "UsageCoreTests", dependencies: ["UsageCore"]),
  ]
)
