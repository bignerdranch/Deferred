//
//  Protected.swift
//  Deferred
//
//  Created by John Gallagher on 7/17/14.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

/// A protected value only allows access from within a locking statement. This
/// prevents accidental unsafe access when thread safety is desired.
public final class Protected<T> {
    // FIXME: These can be made `private` again by re-introducing a
    // `fileprivate var synchronizedValue` when a version of Swift is released
    // with a fix for SR-2623: https://bugs.swift.org/browse/SR-2623
    fileprivate var lock: Locking
    fileprivate var value: T

    /// Creates a protected `value` with a type implementing a `lock`.
    public init(initialValue value: T, lock: Locking = NativeLock()) {
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
}

extension Protected: CustomDebugStringConvertible, CustomReflectable {
    public var debugDescription: String {
        guard let lock = lock as? MaybeLocking else {
            return "\(type(of: self))"
        }

        return lock.withAttemptedReadLock {
            "\(type(of: self))(\(String(reflecting: value)))"
        } ?? "\(type(of: self)) (lock contended)"
    }

    public var customMirror: Mirror {
        guard let lock = lock as? MaybeLocking else {
            return Mirror(self, children: [ "locked": "unknown" ], displayStyle: .tuple)
        }

        return lock.withAttemptedReadLock {
            Mirror(self, children: [ "item": value ], displayStyle: .optional)
        } ?? Mirror(self, children: [ "lockContended": true ], displayStyle: .tuple)
    }
}
