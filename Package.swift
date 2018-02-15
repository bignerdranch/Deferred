// swift-tools-version:4.0

//
//  Package.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/7/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import PackageDescription

let package = Package(
    name: "Deferred",
    products: [
        .library(name: "Deferred", type: .dynamic, targets: [ "Deferred", "Task" ])
    ],
    targets: [
        .target(name: "Atomics"),
        .target(
            name: "Deferred",
            dependencies: [ "Atomics" ]),
        .testTarget(
            name: "DeferredTests",
            dependencies: [ "Deferred" ],
            exclude: [ "Tests/AllTestsCommon.swift" ]),
        .target(
            name: "Task",
            dependencies: [ "Deferred" ]),
        .testTarget(
            name: "TaskTests",
            dependencies: [ "Deferred", "Task" ],
            exclude: [ "Tests/AllTestsCommon.swift" ])
    ],
    swiftLanguageVersions: [ 4 ])
