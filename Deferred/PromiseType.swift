//
//  PromiseType.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

public protocol PromiseType {
    typealias Value

    /// Check whether or not the receiver is filled.
    var isFilled: Bool { get }

    /// Determines the deferred value with a given result.
    ///
    /// Filling a deferred value should usually be attempted only once, and by
    /// default filling will trap upon improper usage.
    ///
    /// * In playgrounds and unoptimized builds (the default for a "Debug"
    ///   configuration), program execution will be stopped at the caller in
    ///   a debuggable state.
    /// * In -O builds (the default for a "Release" configuration), program
    ///   execution will stop.
    /// * In -Ounchecked builds, the programming error is assumed to not exist.
    ///
    /// If your deferred requires multiple potential fillers to race, you may
    /// disable the precondition.
    ///
    /// :param: value The resolved value of the deferred.
    /// :param: assertIfFilled If `false`, race checking is disabled.
    func fill(value: Value, assertIfFilled: Bool, file: StaticString, line: UInt)
}
