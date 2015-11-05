//
//  FutureCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

public extension SequenceType where Generator.Element: FutureType {
    /// Choose the future that is determined first from a collection of futures.
    ///
    /// - returns: A deferred value that is determined with the first of the
    ///   given futures to be determined.
    var firstFuture: Deferred<Generator.Element.Value> {
        let combined = Deferred<Generator.Element.Value>()
        for d in self {
            d.upon { t in combined.fill(t, assertIfFilled: false) }
        }
        return combined
    }
}

public extension CollectionType where Generator.Element: FutureType {
    /// Compose a number of futures into a single deferred array.
    ///
    /// - returns: A deferred array that is determined once all the given values
    ///   are determined, in the same order.
    var allFutures: Deferred<[Generator.Element.Value]> {
        if isEmpty {
            return Deferred(value: [])
        }

        let array = Array(self)
        let combined = Deferred<[Generator.Element.Value]>()
        let group = dispatch_group_create()

        for deferred in array {
            dispatch_group_enter(group)
            deferred.upon { _ in
                dispatch_group_leave(group)
            }
        }

        dispatch_group_notify(group, genericQueue) {
            let results = array.map { $0.value }
            combined.fill(results, assertIfFilled: true)
        }

        return combined
    }
}
