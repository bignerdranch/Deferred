//
//  ResultFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/26/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif
import Dispatch

extension Future where Value: Either, Value.Left == Error {
    /// Create a future having the same underlying task as `other`.
    public init<Other: FutureProtocol>(task other: Other)
        where Other.Value: Either, Other.Value.Left == Value.Left, Other.Value.Right == Value.Right {
        if let asSelf = other as? Future<Value> {
            self.init(asSelf)
        } else {
            self.init(other.every {
                Value(from: $0.extract)
            })
        }
    }

    /// Create a future having the same underlying task as `other`.
    public init<Other: FutureProtocol>(success other: Other) where Other.Value == Value.Right {
        self.init(other.every(per: Value.init(right:)))
    }
}
