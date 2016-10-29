//
//  FutureCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

extension Sequence where Iterator.Element: FutureProtocol {
    /// Chooses the future that is determined first from `self`.
    public func firstFilled() -> Future<Iterator.Element.Value> {
        let combined = Deferred<Iterator.Element.Value>()
        for future in self {
            future.upon(DispatchQueue.global(qos: .utility)) {
                combined.fill(with: $0)
            }
        }
        return Future(combined)
    }
}

private struct AllFilledFuture<Value>: FutureProtocol {
    let group = DispatchGroup()
    let combined = Deferred<[Value]>()

    fileprivate init<Base: Collection>(base: Base) where Base.Iterator.Element: FutureProtocol, Base.Iterator.Element.Value == Value {
        let array = Array(base)
        let queue = DispatchQueue.global(qos: .utility)

        for future in array {
            group.enter()
            future.upon(queue) { [group] _ in
                group.leave()
            }
        }

        group.notify(queue: queue) { [combined] in
            combined.fill(with: array.map { $0.value })
        }
    }

    func upon(_ executor: Executor, execute body: @escaping([Value]) -> Void) {
        combined.upon(executor, execute: body)
    }

    func wait(until time: DispatchTime) -> [Value]? {
        return combined.wait(until: time)
    }
}

extension Collection where Iterator.Element: FutureProtocol {
    /// Composes a number of futures into a single deferred array.
    public func allFilled() -> Future<[Iterator.Element.Value]> {
        guard !isEmpty else {
            return Future(value: [])
        }

        return Future(AllFilledFuture(base: self))
    }
}
