//
//  Protected.swift
//  Deferred
//
//  Created by John Gallagher on 7/17/14.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

/// A protected value only allows access from within a locking statement. This
/// prevents accidental unsafe access when thread safety is desired.
public final class Protected<T> {
    @usableFromInline
    internal final var lock: Locking
    @usableFromInline
    internal final var unsafeValue: T

    /// Creates a protected `value` with a type implementing a `lock`.
    public init(initialValue value: T, lock: Locking = NativeLock()) {
        self.unsafeValue = value
        self.lock = lock
    }

    /// Give read access to the item within `body`.
    /// - parameter body: A function that reads from the contained item.
    /// - returns: The value returned from the given function.
    @inlinable
    public func withReadLock<Return>(_ body: (T) throws -> Return) rethrows -> Return {
        return try lock.withReadLock {
            try body(unsafeValue)
        }
    }

    /// Give write access to the item within the given function.
    /// - parameter body: A function that writes to the contained item, and returns some value.
    /// - returns: The value returned from the given function.
    @inlinable
    public func withWriteLock<Return>(_ body: (inout T) throws -> Return) rethrows -> Return {
        return try lock.withWriteLock {
            try body(&unsafeValue)
        }
    }
}

extension Protected: CustomDebugStringConvertible, CustomReflectable {
    public var debugDescription: String {
        var ret = "Protected("
        if lock.withAttemptedReadLock({
            debugPrint(unsafeValue, terminator: "", to: &ret)
        }) == nil {
            ret.append("locked")
        }
        ret.append(")")
        return ret
    }

    public var customMirror: Mirror {
        let child: Mirror.Child = lock.withAttemptedReadLock {
            (label: "value", value: unsafeValue)
        } ?? (label: "isLocked", value: true)
        return Mirror(self, children: CollectionOfOne(child), displayStyle: .optional)
    }
}
