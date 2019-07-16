// swift-tools-version:4.1

//
//  Package.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/7/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

import PackageDescription

let package = Package(
    name: "Deferred",
    products: [
        .library(name: "Deferred", targets: [ "Deferred", "Task" ])
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
    ])
