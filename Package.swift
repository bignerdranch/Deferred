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
    targets: [
        Target(name: "Atomics"),
        Target(name: "Deferred", dependencies: [
			.Target(name: "Atomics")
        ]),
        Target(name: "Result"),
        Target(name: "Task", dependencies: [
            .Target(name: "Deferred"),
            .Target(name: "Result")
        ]),

        Target(name: "TestSupport", dependencies: [
            .Target(name: "Deferred"),
            .Target(name: "Result"),
            .Target(name: "Task"),
        ]),

        Target(name: "DeferredTests", dependencies: [
            .Target(name: "TestSupport"),
            .Target(name: "Deferred"),
        ]),
        Target(name: "ResultTests", dependencies: [
            .Target(name: "TestSupport"),
            .Target(name: "Result"),
        ]),
        Target(name: "TaskTests", dependencies: [
            .Target(name: "TestSupport"),
            .Target(name: "Task"),
        ]),
    ]
)

let dylib = Product(name: "Deferred", type: .Library(.Dynamic), modules: "Deferred", "Result", "Task")
products.append(dylib)
