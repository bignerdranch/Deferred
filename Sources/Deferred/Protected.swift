//
//  Protected.swift
//  Locking
//
//  Created by John Gallagher on 7/17/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

/// A protected value only allows access from within a locking statement. This
/// prevents accidental unsafe access when thread safety is desired.
public final class Protected<T> {
    private var lock: Locking
    private var value: T

    /// Creates a protected `value` with a type implementing a `lock`.
    public init(initialValue value: T, lock: Locking = CASSpinLock()) {
        self.value = value
        self.lock = lock
    }

    /// Give read access to the item within `body`.
    /// - parameter body: A function that reads from the contained item.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(_ body: (T) throws -> Return) rethrows -> Return {
        return try lock.withReadLock {
            try body(value)
        }
    }

    /// Give write access to the item within the given function.
    /// - parameter body: A function that writes to the contained item, and returns some value.
    /// - returns: The value returned from the given function.
    public func withWriteLock<Return>(_ body: (inout T) throws -> Return) rethrows -> Return {
        return try lock.withWriteLock {
            try body(&value)
        }
    }

    fileprivate var synchronizedValue: T? {
        return lock.withAttemptedReadLock { value }
    }
}

extension Protected: CustomDebugStringConvertible, CustomReflectable {
    public var debugDescription: String {
        if let value = synchronizedValue {
            return "Protected(\(String(reflecting: value)))"
        } else {
            return "\(type(of: self)) (lock contended)"
        }
    }

    public var customMirror: Mirror {
        if let value = synchronizedValue {
            return Mirror(self, children: [ "item": value ], displayStyle: .optional)
        } else {
            return Mirror(self, children: [ "lockContended": true ], displayStyle: .tuple)
        }
    }
}
