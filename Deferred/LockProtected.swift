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

    /**
    Give read access to the item within the given function.

    :param: block A function that reads from the contained item.
    :returns: The value returned from the given function.
    */
    public func withReadLock<U>(body: T -> U) -> U {
        return lock.withReadLock { [unowned self] in
            return body(self.item)
        }
    }

    /**
    Give write access to the item within the given function.

    :param: block A function that writes to the contained item, and returns some
    value.

    :returns: The value returned from the given function.
    */
    public func withWriteLock<U>(body: (inout T) -> U) -> U {
        return lock.withWriteLock { [unowned self] in
            return body(&self.item)
        }
    }
}
