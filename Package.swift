// swift-tools-version:5.1

//
//  Package.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/7/15.
//  Copyright © 2015-2020 Big Nerd Ranch. Licensed under MIT.
//

import PackageDescription

let package = Package(
    name: "Deferred",
    platforms: [
        .macOS(.v10_12), .iOS(.v10), .watchOS(.v3), .tvOS(.v10)
    ],
    products: [
        .library(name: "Deferred", targets: [ "Deferred", "Task" ])
    ],
    targets: [
        .target(
            name: "Deferred",
            dependencies: [ "CAtomics" ]),
        .testTarget(
            name: "DeferredTests",
            dependencies: [ "Deferred" ],
            exclude: [ "Tests/AllTestsCommon.swift" ]),
        .target(
            name: "Task",
            dependencies: [ "Deferred", "CAtomics" ]),
        .testTarget(
            name: "TaskTests",
            dependencies: [ "Deferred", "Task" ],
            exclude: [ "Tests/AllTestsCommon.swift" ]),
        .target(name: "CAtomics")
    ])
