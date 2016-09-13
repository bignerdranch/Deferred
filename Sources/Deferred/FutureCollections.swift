//
//  FutureCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
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

extension Collection where Iterator.Element: FutureProtocol {
    /// Composes a number of futures into a single deferred array.
    public func allFilled() -> Future<[Iterator.Element.Value]> {
        if isEmpty {
            return Future(value: [])
        }

        let array = Array(self)
        let combined = Deferred<[Iterator.Element.Value]>()
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .utility)

        for deferred in array {
            group.enter()
            deferred.upon(queue) { _ in
                group.leave()
            }
        }

        group.notify(queue: queue) {
            combined.fill(with: array.map {
                $0.value
            })
        }

        return Future(combined)
    }
}
