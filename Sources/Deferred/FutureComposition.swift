//
//  FutureComposition.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

extension FutureProtocol {
    /// Returns a value that becomes determined after both the callee and the
    /// given future become determined.
    ///
    /// - seealso: SequenceType.joinedValues
    public func and<OtherFuture: FutureProtocol>(_ other: OtherFuture) -> Future<(Value, OtherFuture.Value)> {
        let queue = DispatchQueue.any()
        return andThen(upon: queue) { t in
            other.map(upon: queue) { u in (t, u) }
        }
    }

    /// Returns a value that becomes determined after the callee and both other
    /// futures become determined.
    ///
    /// - seealso: SequenceType.joinedValues
    public func and<Other1: FutureProtocol, Other2: FutureProtocol>(_ one: Other1, _ two: Other2) -> Future<(Value, Other1.Value, Other2.Value)> {
        let queue = DispatchQueue.any()
        return andThen(upon: queue) { t in
            one.andThen(upon: queue) { u in
                two.map(upon: queue) { v in (t, u, v) }
            }
        }
    }

    /// Returns a value that becomes determined after the callee and all other
    /// futures become determined.
    ///
    /// - seealso: SequenceType.joinedValues
    public func and<Other1: FutureProtocol, Other2: FutureProtocol, Other3: FutureProtocol>(_ one: Other1, _ two: Other2, _ three: Other3) -> Future<(Value, Other1.Value, Other2.Value, Other3.Value)> {
        let queue = DispatchQueue.any()
        return andThen(upon: queue) { t in
            one.andThen(upon: queue) { u in
                two.andThen(upon: queue) { v in
                    three.map(upon: queue) { w in (t, u, v, w) }
                }
            }
        }
    }
}
