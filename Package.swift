// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Project43",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Project43",
            targets: ["Project43"]
        ),
    ],
    targets: [
        .target(
            name: "Project43",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("HealthKit"),
                .linkedFramework("MapKit"),
                .linkedFramework("CoreLocation")
            ]
        ),
        .testTarget(
            name: "Project43Tests",
            dependencies: ["Project43"]
        ),
    ]
)