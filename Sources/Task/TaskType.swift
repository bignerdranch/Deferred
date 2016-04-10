//
//  TaskType.swift
//  Deferred
//
//  Created by Zachary Waldowski on 3/28/16.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Dispatch

/// A task is a future modelling the completion of some underlying operation,
/// such as making a web request.
///
/// Just like a future, a task is useful a joining mechanism for a value that
/// gets determined later on. But a task adds an extra dimension: the fulfilled
/// value may model an error state, such as recoverable networking failures or
/// cancellation.
///
/// - seealso: FutureType
public protocol TaskType: FutureType {
    /// A type that represents the result of some asynchronous operation.
    associatedtype Value: ResultType

    /// Attempt to cancel the underlying operation.
    ///
    /// An implementation should be a "best effort". There are several
    /// situations in which cancellation may not happen:
    /// * The operation has already completed.
    /// * The operation has entered an uncancelable state.
    /// * The underlying task is not cancelable.
    ///
    /// - seealso: isFilled
    func cancel()
}
