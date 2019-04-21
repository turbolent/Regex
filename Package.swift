// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Regex",
    products: [
        .library(
            name: "Regex",
            targets: ["Regex"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/turbolent/ParserDescription.git", from: "0.6.0"),
        .package(url: "https://github.com/Weebly/OrderedSet.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "Regex",
            dependencies: [
                "ParserDescription",
                "OrderedSet"
            ]
        ),
        .testTarget(
            name: "RegexTests",
            dependencies: [
                "Regex",
                "ParserDescription",
                "ParserDescriptionOperators"
            ]
        ),
    ]
)
