// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tables",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(name: "Tables", targets: ["Tables"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/sqlite-kit.git",
                 .branch("main")),
        .package(name: "Commons",
                 url: "https://github.com/loganwright/commons.git",
                 .branch("main"))
    ],
    targets: [
        .target(name: "Tables",
                dependencies: [
                    "Commons",
//                    "SQLiteKit"
                    .product(name: "SQLiteKit",
                             package: "sqlite-kit"),
//                    .product(
//                        name: "Commons",
//                        package: "Commons")
//                    .product(name: "C", package: <#T##String#>)
                ]),
        .testTarget(
            name: "TablesTests",
            dependencies: ["Tables", .product(name: "Endpoints", package: "Commons")])
    ]
)

