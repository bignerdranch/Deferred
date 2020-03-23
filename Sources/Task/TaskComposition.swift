//
//  TaskComposition.swift
//  Deferred
//
//  Created by Zachary Waldowski on 2/11/20.
//  Copyright © 2020 Big Nerd Ranch. Licensed under MIT.
//

// swiftlint:disable force_cast
// swiftlint:disable function_parameter_count
// swiftlint:disable identifier_name
// swiftlint:disable large_tuple

public extension TaskProtocol {
    private func toAny() -> Task<Any> {
        return everySuccess { $0 as Any }
    }

    /// Returns a value that becomes determined after both the callee and the
    /// given task complete.
    ///
    /// - see: `Collection.allSucceeded()`
    func andSuccess<A: TaskProtocol>(
        of a: A
    ) -> Task<(Success, A.Success)> {
        return [ toAny(), a.toAny() ].allSucceeded().everySuccess { (array) in
            (
                array[0] as! Success,
                array[1] as! A.Success
            )
        }
    }

    /// Returns a value that becomes determined after the callee and both
    /// other tasks complete.
    ///
    /// - see: `Collection.allSucceeded()`
    func andSuccess<A: TaskProtocol, B: TaskProtocol>(
        of a: A, _ b: B
    ) -> Task<(Success, A.Success, B.Success)> {
        return [ toAny(), a.toAny(), b.toAny() ].allSucceeded().everySuccess { (array) in
            (
                array[0] as! Success,
                array[1] as! A.Success,
                array[2] as! B.Success
            )
        }
    }

    /// Returns a value that becomes determined after the callee and all
    /// other tasks complete.
    ///
    /// - see: `Collection.allSucceeded()`
    func andSuccess<A: TaskProtocol, B: TaskProtocol, C: TaskProtocol>(
        of a: A, _ b: B, _ c: C
    ) -> Task<(Success, A.Success, B.Success, C.Success)> {
        return [ toAny(), a.toAny(), b.toAny(), c.toAny() ].allSucceeded().everySuccess { (array) in
            (
                array[0] as! Success,
                array[1] as! A.Success,
                array[2] as! B.Success,
                array[3] as! C.Success
            )
        }
    }

    /// Returns a value that becomes determined after the callee and all
    /// other tasks complete.
    ///
    /// - see: `Collection.allSucceeded()`
    func andSuccess<A: TaskProtocol, B: TaskProtocol, C: TaskProtocol, D: TaskProtocol>(
        of a: A, _ b: B, _ c: C, _ d: D
    ) -> Task<(Success, A.Success, B.Success, C.Success, D.Success)> {
        return [ toAny(), a.toAny(), b.toAny(), c.toAny(), d.toAny() ].allSucceeded().everySuccess { (array) in
            (
                array[0] as! Success,
                array[1] as! A.Success,
                array[2] as! B.Success,
                array[3] as! C.Success,
                array[4] as! D.Success
            )
        }
    }

    /// Returns a value that becomes determined after the callee and all
    /// other tasks complete.
    ///
    /// - see: `Collection.allSucceeded()`
    func andSuccess<A: TaskProtocol, B: TaskProtocol, C: TaskProtocol, D: TaskProtocol, E: TaskProtocol>(
        of a: A, _ b: B, _ c: C, _ d: D, _ e: E
    ) -> Task<(Success, A.Success, B.Success, C.Success, D.Success, E.Success)> {
        return [ toAny(), a.toAny(), b.toAny(), c.toAny(), d.toAny(), e.toAny() ].allSucceeded().everySuccess { (array) in
            (
                array[0] as! Success,
                array[1] as! A.Success,
                array[2] as! B.Success,
                array[3] as! C.Success,
                array[4] as! D.Success,
                array[5] as! E.Success
            )
        }
    }

    /// Returns a value that becomes determined after the callee and all
    /// other tasks complete.
    ///
    /// - see: `Collection.allSucceeded()`
    func andSuccess<A: TaskProtocol, B: TaskProtocol, C: TaskProtocol, D: TaskProtocol, E: TaskProtocol, F: TaskProtocol>(
        of a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F
    ) -> Task<(Success, A.Success, B.Success, C.Success, D.Success, E.Success, F.Success)> {
        return [ toAny(), a.toAny(), b.toAny(), c.toAny(), d.toAny(), e.toAny(), f.toAny() ].allSucceeded().everySuccess { (array) in
            (
                array[0] as! Success,
                array[1] as! A.Success,
                array[2] as! B.Success,
                array[3] as! C.Success,
                array[4] as! D.Success,
                array[5] as! E.Success,
                array[6] as! F.Success
            )
        }
    }

    /// Returns a value that becomes determined after the callee and all
    /// other tasks complete.
    ///
    /// - see: `Collection.allSucceeded()`
    func andSuccess<A: TaskProtocol, B: TaskProtocol, C: TaskProtocol, D: TaskProtocol, E: TaskProtocol, F: TaskProtocol, G: TaskProtocol>(
        of a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G
    ) -> Task<(Success, A.Success, B.Success, C.Success, D.Success, E.Success, F.Success, G.Success)> {
        return [ toAny(), a.toAny(), b.toAny(), c.toAny(), d.toAny(), e.toAny(), f.toAny(), g.toAny() ].allSucceeded().everySuccess { (array) in
            (
                array[0] as! Success,
                array[1] as! A.Success,
                array[2] as! B.Success,
                array[3] as! C.Success,
                array[4] as! D.Success,
                array[5] as! E.Success,
                array[6] as! F.Success,
                array[7] as! G.Success
            )
        }
    }
}
