//
//  FutureCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

extension Sequence where Iterator.Element: FutureType {
    /// Choose the future that is determined first from a collection of futures.
    ///
    /// - returns: A deferred value that is determined with the first of the
    ///   given futures to be determined.
    public var earliestFilled: Future<Iterator.Element.Value> {
        let combined = Deferred<Iterator.Element.Value>()
        for future in self {
            future.upon {
                combined.fill($0)
            }
        }
        return Future(combined)
    }
}

extension Collection where Iterator.Element: FutureType {
    /// Compose a number of futures into a single deferred array.
    ///
    /// - returns: A deferred array that is determined once all the given values
    ///   are determined, in the same order.
    public var joinedValues: Future<[Iterator.Element.Value]> {
        if isEmpty {
            return Future(value: [])
        }

        let array = Array(self)
        let combined = Deferred<[Iterator.Element.Value]>()
        let group = DispatchGroup()

        for deferred in array {
            group.enter()
            deferred.upon { _ in
                group.leave()
            }
        }

        group.notify(queue: Iterator.Element.genericQueue) {
            combined.fill(array.map {
                $0.value
            })
        }

        return Future(combined)
    }
}
