//
//  LockProtected.swift
//  ReadWriteLock
//
//  Created by John Gallagher on 7/17/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

/// A `LockProtected` holds onto a value of type T, but only allows access to it
/// from within a locking statement. This prevents accidental unsafe access when
/// thread safety is desired.
public final class LockProtected<T> {
    private var lock: ReadWriteLock
    private var item: T

    /// Create the protected value with an initial item and a default lock.
    public convenience init(item: T) {
        self.init(item: item, lock: CASSpinLock())
    }

    /// Create the protected value with an initial item and a type implementing
    /// a lock.
    public init(item: T, lock: ReadWriteLock) {
        self.item = item
        self.lock = lock
    }

    /// Give read access to the item within `body`.
    /// - parameter body: A function that reads from the contained item.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(@noescape body: T throws -> Return) rethrows -> Return {
        return try lock.withReadLock {
            try body(self.item)
        }
    }

    /// Give write access to the item within the given function.
    /// - parameter body: A function that writes to the contained item, and returns some value.
    /// - returns: The value returned from the given function.
    public func withWriteLock<Return>(@noescape body: (inout T) throws -> Return) rethrows -> Return {
        return try lock.withWriteLock {
            try body(&self.item)
        }
    }

    private var synchronizedValue: T? {
        return lock.withAttemptedReadLock { self.item }
    }
}

extension LockProtected: CustomDebugStringConvertible, CustomReflectable {

    /// A textual representation of `self`, suitable for debugging.
    public var debugDescription: String {
        if let value = synchronizedValue {
            return "LockProtected(\(String(reflecting: value)))"
        } else {
            return "\(self.dynamicType) (lock contended)"
        }
    }

    /// Returns the `Mirror` for `self`.
    public func customMirror() -> Mirror {
        if let value = synchronizedValue {
            return Mirror(self, children: [ "item": value ], displayStyle: .Optional)
        } else {
            return Mirror(self, children: [ "lockContended": true ], displayStyle: .Tuple)
        }
    }

}
