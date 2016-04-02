//
//  FutureComposition.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension FutureType {
    /// Composes this future with another.
    ///
    /// - parameter other: Any other future.
    /// - returns: A value that becomes determined after both the reciever and
    ///   the given future become determined.
    /// - seealso: SequenceType.allFutures
    public func and<OtherFuture: FutureType>(other: OtherFuture) -> Future<(Value, OtherFuture.Value)> {
        return flatMap { t in other.map { u in (t, u) } }
    }
    
    /// Composes this future with others.
    ///
    /// - parameter one: Some other future to join with.
    /// - parameter two: Some other future to join with.
    /// - returns: A value that becomes determined after the reciever and both
    ///   other futures become determined.
    /// - seealso: SequenceType.allFutures
    public func and<Other1: FutureType, Other2: FutureType>(one: Other1, _ two: Other2) -> Future<(Value, Other1.Value, Other2.Value)> {
        return flatMap { t in
            one.flatMap { u in
                two.map { v in (t, u, v) }
            }
        }
    }
    
    /// Composes this future with others.
    ///
    /// - parameter one: Some other future to join with.
    /// - parameter two: Some other future to join with.
    /// - parameter three: Some other future to join with.
    /// - returns: A value that becomes determined after the reciever and both
    ///   other futures become determined.
    /// - seealso: SequenceType.allFutures
    public func and<Other1: FutureType, Other2: FutureType, Other3: FutureType>(one: Other1, _ two: Other2, _ three: Other3) -> Future<(Value, Other1.Value, Other2.Value, Other3.Value)> {
        return flatMap { t in
            one.flatMap { u in
                two.flatMap { v in
                    three.map { w in (t, u, v, w) }
                }
            }
        }
    }
}
