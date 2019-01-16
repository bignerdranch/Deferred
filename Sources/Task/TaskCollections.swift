//
//  TaskCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 11/18/15.
//  Copyright © 2015-2019 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif
import Dispatch
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation
#endif

private struct AllFilled<Success>: TaskProtocol {
    let group = DispatchGroup()
    let combined = Deferred<Task<Success>.Result>()
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    let progress = Progress()
    #else
    let cancellations: [() -> Void]
    #endif

    init<Base: Collection>(_ base: Base, mappingBy transform: @escaping([Base.Element]) -> Success) where Base.Element: TaskProtocol {
        let array = Array(base)
        let queue = DispatchQueue.global(qos: .utility)

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        progress.totalUnitCount = numericCast(array.count)
        #else
        self.cancellations = array.map { $0.cancel }
        #endif

        for future in array {
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            if let task = future as? Task<Base.Element.Success> {
                progress.monitorChild(task.progress, withPendingUnitCount: 1)
            } else {
                progress.monitorCompletion(of: future, withPendingUnitCount: 1)
            }
            #endif

            group.enter()
            future.upon(queue) { [combined, group] (result) in
                do {
                    _ = try result.get()
                } catch {
                    combined.fail(with: error)
                }

                group.leave()
            }
        }

        group.notify(queue: queue) { [combined] in
            combined.succeed(with: transform(array))
        }
    }

    func upon(_ executor: Executor, execute body: @escaping(Task<Success>.Result) -> Void) {
        combined.upon(executor, execute: body)
    }

    func peek() -> Task<Success>.Result? {
        return combined.peek()
    }

    func wait(until time: DispatchTime) -> Task<Success>.Result? {
        return combined.wait(until: time)
    }

    #if !os(macOS) && !os(iOS) && !os(tvOS) && !os(watchOS)
    func cancel() {
        for cancellation in cancellations {
            cancellation()
        }
    }
    #endif
}

extension Collection where Element: TaskProtocol {
    /// Compose a number of tasks into a single array.
    ///
    /// If any of the contained tasks fail, the returned task will be determined
    /// with that failure. Otherwise, once all operations succeed, the returned
    /// task will be fulfilled by combining the values.
    public func allSucceeded() -> Task<[Element.Success]> {
        guard !isEmpty else {
            return Task(success: [])
        }

        let wrapper = AllFilled(self) { (array) -> [Element.Success] in
            // Expect each to be filled but not successful right now.
            // swiftlint:disable:next force_unwrapping
            return array.compactMap { try? $0.peek()!.get() }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task(wrapper, progress: wrapper.progress)
        #else
        return Task(wrapper, uponCancel: wrapper.cancel)
        #endif
    }
}

extension Collection where Element: TaskProtocol, Element.Success == Void {
    /// Compose a number of tasks into a single array.
    ///
    /// If any of the contained tasks fail, the returned task will be determined
    /// with that failure. Otherwise, once all operations succeed, the returned
    /// task will be determined a success.
    public func allSucceeded() -> Task<Void> {
        guard !isEmpty else {
            return Task(success: ())
        }

        let wrapper = AllFilled(self) { _ in () }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task(wrapper, progress: wrapper.progress)
        #else
        return Task(wrapper, uponCancel: wrapper.cancel)
        #endif
    }
}
