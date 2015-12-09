//
//  MemoStore.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/8/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

// Extremely simple surface describing an async rejoin-type notifier for a
// one-off event.
protocol CallbacksList {
    
    init()
    
    var isCompleted: Bool { get }
    
    /// Unblock the waiter list.
    ///
    /// - precondition: `isCompleted` is false.
    /// - postcondition: `isCompleted` is true.
    func markCompleted()
    
    /// Become notified when the list becomes unblocked.
    ///
    /// If `isCompleted`, an implementer should immediately submit the `body`
    /// to `queue`.
    func notify(upon queue: dispatch_queue_t, body: dispatch_block_t)
    
}
