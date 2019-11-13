//
//  FutureCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
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

private struct AllFilledFuture<Element>: FutureProtocol {
    let combined = Deferred<[Element]>()

    init<Base: Collection>(base: Base) where Base.Iterator.Element: FutureProtocol, Base.Iterator.Element.Value == Element {
        let array = Array(base)
        guard !array.isEmpty else {
            combined.fill(with: [])
            return
        }

        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .utility)

        for future in array {
            group.enter()
            future.upon(queue) { [group] _ in
                group.leave()
            }
        }

        group.notify(queue: queue) { [combined] in
            // Expect each to be filled right now.
            // swiftlint:disable:next force_unwrapping
            combined.fill(with: array.map({ $0.peek()! }))
        }
    }

    func upon(_ executor: Executor, execute body: @escaping([Element]) -> Void) {
        combined.upon(executor, execute: body)
    }

    func wait(until time: DispatchTime) -> [Element]? {
        return combined.wait(until: time)
    }
}

extension Collection where Iterator.Element: FutureProtocol {
    /// Composes a number of futures into a single deferred array.
    public func allFilled() -> Future<[Iterator.Element.Value]> {
        return Future(AllFilledFuture(base: self))
    }
}
