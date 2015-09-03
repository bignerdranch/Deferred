//
//  FutureType.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

public protocol FutureType {
    typealias Value

    /**
    Call some function once the value is determined.

    If the value is already determined, the function will be submitted to the
    queue immediately. An `upon` call is always executed asynchronously.

    :param: queue A dispatch queue for executing the given function on.
    :param: body A function that uses the determined value.
    */
    func upon(queue: dispatch_queue_t, body: Value -> ())

    /**
    Waits synchronously for the value to become determined.

    If the value is already determined, the call returns immediately with the
    value.

    :param: time A length of time to wait for the value to be determined.
    :returns: The determined value, if filled within the timeout, or `nil`.
    */
    func wait(time: Timeout) -> Value?
}
