// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-only
import PackageDescription
let package = Package(
    name: "Markman",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "markman", targets: ["Markman"])],
    targets: [.executableTarget(name: "Markman", resources: [.copy("Resources")])]
)
