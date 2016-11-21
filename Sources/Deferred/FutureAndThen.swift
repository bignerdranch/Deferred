//
//  FutureAndThen.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension FutureProtocol {
    public func andThen<NewFuture: FutureProtocol>(upon executor: PreferredExecutor, start requestNextValue: @escaping(Value) -> NewFuture) -> Future<NewFuture.Value> {
        return andThen(upon: executor as Executor, start: requestNextValue)
    }

    public func andThen<NewFuture: FutureProtocol>(upon executor: Executor, start requestNextValue: @escaping(Value) -> NewFuture) -> Future<NewFuture.Value> {
        let d = Deferred<NewFuture.Value>()
        upon(executor) {
            requestNextValue($0).upon(executor) {
                d.fill(with: $0)
            }
        }
        return Future(d)
    }
}
