//
//  FutureMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension FutureProtocol {
    public func map<NewValue>(upon executor: PreferredExecutor, transform: @escaping(Value) -> NewValue) -> Future<NewValue> {
        return map(upon: executor as Executor, transform: transform)
    }

    public func map<NewValue>(upon executor: Executor, transform: @escaping(Value) -> NewValue) -> Future<NewValue> {
        let d = Deferred<NewValue>()
        upon(executor) {
            d.fill(with: transform($0))
        }
        return Future(d)
    }
}
