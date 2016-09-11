//
//  Package.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/7/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
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
        ])
    ]
)
