//
//  ExecutorType.swift
//  Deferred
//
//  Created by Zachary Waldowski on 3/29/16.
//  Copyright © 2014-2016 Big Nerd Ranch. All rights reserved.
//

import Foundation

public protocol ExecutorType {

    func submit(body: () -> Void)

    var underlyingQueue: dispatch_queue_t? { get }

}

extension ExecutorType {

    public var underlyingQueue: dispatch_queue_t? {
        return nil
    }
    
}

struct QueueExecutor: ExecutorType {

    private let queue: dispatch_queue_t
    init(_ queue: dispatch_queue_t) {
        self.queue = queue
    }

    func submit(body: () -> Void) {
        dispatch_async(queue, body)
    }

    var underlyingQueue: dispatch_queue_t? {
        return queue
    }

}

extension NSOperationQueue: ExecutorType {

    public func submit(body: () -> Void) {
        addOperationWithBlock(body)
    }

}

extension CFRunLoop: ExecutorType {

    public func submit(body: () -> Void) {
        CFRunLoopPerformBlock(self, kCFRunLoopDefaultMode, body)
        CFRunLoopWakeUp(self)
    }

}

extension NSRunLoop: ExecutorType {

    public func submit(body: () -> Void) {
        getCFRunLoop().submit(body)
    }

}

