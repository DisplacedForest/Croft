// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CroftCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "Graph", targets: ["Graph"]),
        .library(name: "Knowledge", targets: ["Knowledge"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Persistence"),
        .target(name: "Graph"),
        .target(name: "Knowledge"),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
        .testTarget(name: "GraphTests", dependencies: ["Graph"]),
        .testTarget(name: "KnowledgeTests", dependencies: ["Knowledge"]),
    ]
)
