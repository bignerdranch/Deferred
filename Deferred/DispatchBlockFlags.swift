//
//  DispatchBlockFlags.swift
//  Deferred
//
//  Created by Zachary Waldowski on 7/28/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

extension dispatch_block_flags_t: RawOptionSetType {

    /// The empty options set.
    public static var allZeros: dispatch_block_flags_t {
        return dispatch_block_flags_t(0)
    }

    /// Converts from a bitmask of `UInt`.
    public init(rawValue: UInt) {
        self.init(rawValue)
    }

    /// Creates an instance initialized with `nil`.
    public init(nilLiteral: ()) {
        self.init(0)
    }

    /// The corresponding bitwise value of the "raw" type.
    public var rawValue: UInt {
        return value
    }

}

/// Return true if `lhs` is equal to `rhs`.
public func ==(lhs: dispatch_block_flags_t, rhs: dispatch_block_flags_t) -> Bool {
    return lhs.value == rhs.value
}
