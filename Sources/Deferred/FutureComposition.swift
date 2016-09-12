//
//  FutureComposition.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension FutureType {
    /// Returns a value that becomes determined after both the callee and the
    /// given future become determined.
    ///
    /// - seealso: SequenceType.joinedValues
    public func and<OtherFuture: FutureType>(_ other: OtherFuture) -> Future<(Value, OtherFuture.Value)> {
        return flatMap { t in other.map { u in (t, u) } }
    }

    /// Returns a value that becomes determined after the callee and both other
    /// futures become determined.
    ///
    /// - seealso: SequenceType.joinedValues
    public func and<Other1: FutureType, Other2: FutureType>(_ one: Other1, _ two: Other2) -> Future<(Value, Other1.Value, Other2.Value)> {
        return flatMap { t in
            one.flatMap { u in
                two.map { v in (t, u, v) }
            }
        }
    }

    /// Returns a value that becomes determined after the callee and all other
    /// futures become determined.
    ///
    /// - seealso: SequenceType.joinedValues
    public func and<Other1: FutureType, Other2: FutureType, Other3: FutureType>(_ one: Other1, _ two: Other2, _ three: Other3) -> Future<(Value, Other1.Value, Other2.Value, Other3.Value)> {
        return flatMap { t in
            one.flatMap { u in
                two.flatMap { v in
                    three.map { w in (t, u, v, w) }
                }
            }
        }
    }
}
