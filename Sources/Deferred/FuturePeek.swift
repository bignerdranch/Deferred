//
//  FuturePeek.swift
//  Deferred
//
//  Created by Zachary Waldowski on 11/6/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

extension FutureProtocol {
    /// By default, calls `wait` with no delay.
    public func peek() -> Value? {
        return wait(until: .now())
    }
}

extension PromiseProtocol where Self: FutureProtocol {
    /// By default, checks for a fulfilled future value.
    public var isFilled: Bool {
        return peek() != nil
    }
}
