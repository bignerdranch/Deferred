//
//  FutureCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

extension SequenceType where Generator.Element: FutureType {
    /// Choose the future that is determined first from a collection of futures.
    ///
    /// - returns: A deferred value that is determined with the first of the
    ///   given futures to be determined.
    public var earliestFilled: Future<Generator.Element.Value> {
        let combined = Deferred<Generator.Element.Value>()
        for future in self {
            future.upon {
                combined.fill($0)
            }
        }
        return Future(combined)
    }
}

extension CollectionType where Generator.Element: FutureType {
    /// Compose a number of futures into a single deferred array.
    ///
    /// - returns: A deferred array that is determined once all the given values
    ///   are determined, in the same order.
    public var joinedValues: Future<[Generator.Element.Value]> {
        if isEmpty {
            return Future(value: [])
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

        dispatch_group_notify(group, Generator.Element.genericQueue) {
            combined.fill(array.map {
                $0.value
            })
        }

        return Future(combined)
    }
}
