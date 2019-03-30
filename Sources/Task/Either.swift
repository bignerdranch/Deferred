//
//  Either.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2019 Big Nerd Ranch. Licensed under MIT.
//

/// A type that can exclusively represent one of two values.
///
/// By design, an either is symmetrical and treats its variants the same.
/// For representing the most common case of success and failures, prefer
/// a result type like `TaskResult`.
///
/// This protocol describes a minimal interface for representing a result type
/// to overcome limitations with Swift. It is expected that it will be removed
/// completely at some later point.
@available(swift, deprecated: 100000)
public protocol Either {
    /// One of the two possible results.
    ///
    /// By convention, the left side indicates failure, typically through a
    /// Swift `Error`.
    ///
    /// A `typealias` instead of an `associatedtype` to avoid breaking
    /// compatibility when what we actually want becomes representable. See also
    /// <https://github.com/apple/swift/blob/master/docs/LibraryEvolution.rst#protocols>.
    typealias Left = Error

    /// One of the two possible results.
    ///
    /// By convention, the right side is used to hold a correct value.
    associatedtype Right

    /// Creates a left-biased instance.
    init(left: Left)

    /// Creates a right-biased instance.
    init(right: Right)

    /// Creates an instance by evaluating a throwing `body`, capturing its
    /// returned value as a right bias, or the thrown error as a left bias.
    init(catching body: () throws -> Right)

    /// Returns the right-biased value as a throwing expression.
    ///
    /// Use this method to retrieve the value of this instance if it is
    /// right-biased or to throw the error if it is left-biased.
    func get() throws -> Right
}

extension Either {
    @available(*, unavailable, renamed: "get()", message: "Replace with 'get()' to better align with SE-0235, the Swift 5 Result type.")
    public func extract() throws -> Right {
        fatalError("unavailable methods cannot be called")
    }

    @available(*, unavailable, message: "Replace with 'get()' inside a 'do' / 'catch' block to better align with SE-0235, the Swift 5 Result type.")
    public func withValues<Return>(ifLeft left: (Left) throws -> Return, ifRight right: (Right) throws -> Return) rethrows -> Return {
        fatalError("unavailable methods cannot be called")
    }

    @available(*, unavailable, renamed: "init(catching:)", message: "Replace with 'init(catching:)' to align with SE-0235, the Swift 5 Result type.")
    public init<Body>(from body: Body) {
        fatalError("unavailable initializer cannot be called")
    }
}
