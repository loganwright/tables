// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tables",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(name: "Tables", targets: ["Tables"])
    ],
    dependencies: [
        .package(url: "https://github.com/loganwright/sqlite-kit.git",
                 .branch("master")),
        .package(name: "Commons",
                 url: "~/Desktop/mishmash",
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

