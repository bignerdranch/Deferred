//
//  DispatchBlockFlags.swift
//  Deferred
//
//  Created by Zachary Waldowski on 7/28/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

extension dispatch_block_flags_t: RawOptionSetType {

    public static var allZeros: dispatch_block_flags_t {
        return dispatch_block_flags_t(0)
    }

    public init(rawValue: UInt) {
        self.init(rawValue)
    }

    public init(nilLiteral: ()) {
        self.init(0)
    }

    public var rawValue: UInt {
        return value
    }

}

public func ==(lhs: dispatch_block_flags_t, rhs: dispatch_block_flags_t) -> Bool {
    return lhs.value == rhs.value
}
