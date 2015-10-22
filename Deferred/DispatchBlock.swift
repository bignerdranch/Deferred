import Foundation

extension dispatch_block_flags_t: OptionSetType {

    /// Flag indicating that a dispatch block should act as a barrier when
    /// submitted to a concurrent dispatch queue, such that the queue delays
    /// execution of the barrier block until all blocks submitted before the
    /// barrier finish executing.
    /// - note: This flag has no effect when the block is invoked directly.
    /// - seealso: dispatch_barrier_async(_:_:)
    public static var Barrier: dispatch_block_flags_t { return DISPATCH_BLOCK_BARRIER }

    /// Flag indicating that a dispatch block should execute disassociated
    /// from current execution context attributes such as QOS class.
    ///
    ///  - If invoked directly, the block object will remove these attributes
    ///    from the calling queue for the duration of the block.
    ///  - If submitted to a queue, the block object will be executed with the
    ///    attributes of the queue (or any attributes specifically assigned to
    ///    the dispatch block).
    public static var DetachContext: dispatch_block_flags_t { return DISPATCH_BLOCK_DETACHED }

    /// Flag indicating that a dispatch block should be assigned the execution
    /// context attributes that are current at the time the block is created.
    /// This applies to attributes such as QOS class.
    ///
    ///  - If invoked directly, the block will apply the attributes to the
    ///    calling queue for the duration of the block body.
    ///  - If the block object is submitted to a queue, this flag replaces the
    ///    default behavior of associating the submitted block instance with the
    ///    current execution context attributes at the time of submission.
    ///
    /// If a specific QOS class is added or removed during block creation, that
    /// QOS class takes precedence over the QOS class assignment indicated by
    /// this flag.
    /// - seealso: DispatchBlock.Flags.RemoveQOS
    /// - seealso: DispatchBlock(flags:QOS:priority:body:)
    public static var CurrentContext: dispatch_block_flags_t { return DISPATCH_BLOCK_ASSIGN_CURRENT }

    /// Flag indicating that a dispatch block should be not be assigned a QOS
    /// class.
    ///
    ///  - If invoked directly, the block object will be executed with the QOS
    ///    class of the calling queue.
    ///  - If the block is submitted to a queue, this replaces the default
    ///    behavior of associating the submitted block instance with the QOS
    ///    class current at the time of submission.
    ///
    /// This flag is ignored if a specific QOS class is added during block
    /// creation.
    /// - seealso: DispatchBlock(flags:QOS:priority:body:)
    public static var RemoveQOS: dispatch_block_flags_t { return DISPATCH_BLOCK_NO_QOS_CLASS }

    /// Flag indicating that execution of a dispatch block submitted to a queue
    /// should prefer the QOS class assigned to the queue over the QOS class
    /// assigned during block creation. The latter will only be used if the
    /// queue in question does not have an assigned QOS class, as long as doing
    /// so does not result in a QOS class lower than the QOS class inherited
    /// from the queue's target queue.
    ///
    /// This flag is the default when a dispatch block is submitted to a queue
    /// for asynchronous execution and has no effect when the dispatch block
    /// is invoked directly.
    /// - note: This flag is ignored if `EnforceQOS` is also passed.
    /// - seealso: DispatchBlock.Flags.Enforce
    public static var InheritQOS: dispatch_block_flags_t { return DISPATCH_BLOCK_INHERIT_QOS_CLASS }

    /// Flag indicating that execution of a dispatch block submitted to a queue
    /// should prefer the QOS class assigned to the block at the time of
    /// submission over the QOS class assigned to the queue, as long as doing so
    /// will not result in a lower QOS class.
    ///
    /// This flag is the default when a dispatch block is submitted to a queue
    /// for synchronous execution or when the dispatch block object is invoked
    /// directly.
    /// - seealso: dispatch_sync(_:_:)
    public static var EnforceQOS: dispatch_block_flags_t { return DISPATCH_BLOCK_ENFORCE_QOS_CLASS }

}

/// A cancellable wrapper for a GCD block.
// Does some trickery to work around <rdar://22432170>. Swift 2.1 will
// remove the `@convention(c)` jazz, making this type optional
@available(OSX 10.10, iOS 8.0, *)
public struct DispatchBlock {

    public typealias Flags = dispatch_block_flags_t

    typealias Block = @convention(block) () -> Void
    private static let cCreate:     @convention(c) (Flags, dispatch_block_t) -> Block! = dispatch_block_create
    private static let cCreateQOS:  @convention(c) (Flags, dispatch_qos_class_t, Int32, dispatch_block_t) -> Block! = dispatch_block_create_with_qos_class
    private static let cPerform:    @convention(c) (Flags, dispatch_block_t) -> Void = dispatch_block_perform
    private static let cWait:       @convention(c) (Block, dispatch_time_t) -> Int = dispatch_block_wait
    private static let cNotify:     @convention(c) (Block, dispatch_queue_t, Block) -> Void = dispatch_block_notify
    private static let cCancel:     @convention(c) Block -> Void = dispatch_block_cancel
    private static let cTestCancel: @convention(c) Block -> Int = dispatch_block_testcancel
    private static let cSync:       @convention(c) (dispatch_queue_t, Block) -> Void = dispatch_sync
    private static let cAsync:      @convention(c) (dispatch_queue_t, Block) -> Void = dispatch_async
    private static let cAfter:      @convention(c) (dispatch_time_t, dispatch_queue_t, Block) -> Void = dispatch_after

    private let block: Block

    /// Create a new dispatch block from an existing function and flags.
    ///
    /// The dispatch block is intended to be submitted to a dispatch queue, but
    /// may also be invoked directly. Both operations can be performed an
    /// arbitrary number of times, but only the first completed execution of a
    /// dispatch block can be waited on or notified for.
    ///
    /// If a dispatch block is submitted to a dispatch queue, the submitted
    /// instance will be associated with the QOS class current at the time of
    /// submission, unless a `DispatchBlock.Flag` is specified to the contrary.
    ///
    /// If a dispatch block is submitted to a serial queue and is configured
    /// to execute with a specific QOS, the system will make a best effort to
    /// apply the necessary QOS overrides to ensure that blocks submitted
    /// earlier to the serial queue are executed at that same QOS class or
    /// higher.
    ///
    /// - parameter flags: Configuration flags for the block
    /// - parameter function: The body of the dispatch block
    public init(flags: dispatch_block_flags_t = [], body: dispatch_block_t) {
        block = DispatchBlock.cCreate(flags, body)
    }

    /// Create a new dispatch block from an existing block and flags, assigning
    /// it the given QOS class and priority.
    ///
    /// The dispatch block is intended to be submitted to a dispatch queue, but
    /// may also be invoked directly. Both operations can be performed an
    /// arbitrary number of times, but only the first completed execution of a
    /// dispatch block can be waited on or notified for.
    ///
    /// If a dispatch block is submitted to a dispatch queue, the submitted
    /// instance will be associated with the QOS class current at the time of
    /// submission, unless a `DispatchBlock.Flag` is specified to the contrary.
    ///
    /// If a dispatch block is submitted to a serial queue and is configured
    /// to execute with a specific QOS, the system will make a best effort to
    /// apply the necessary QOS overrides to ensure that blocks submitted
    /// earlier to the serial queue are executed at that same QOS class or
    /// higher.
    ///
    /// - parameter flags: Configuration flags for the block
    /// - parameter QOS: A QOS class value. Passing `QOS_CLASS_UNSPECIFIED` is
    ///   equivalent to specifying the `DispatchBlock.Flags.RemoveQOS` flag.
    /// - parameter priority: A relative priority within the QOS class.
    ///   This value is an offset in the range `QOS_MIN_RELATIVE_PRIORITY...0`.
    /// - parameter function: The body of the dispatch block
    public init(flags: dispatch_block_flags_t, QOS: dispatch_qos_class_t, priority: Int32, body: dispatch_block_t) {
        assert(priority <= 0 && priority > QOS_MIN_RELATIVE_PRIORITY)
        block = DispatchBlock.cCreateQOS(flags, QOS, priority, body)
    }

    /// Create and synchronously execute a dispatch block with override flags.
    ///
    /// This method behaves identically to creating a new `DispatchBlock`
    /// instance and calling `callAndWait(upon:)`, but may be implemented
    /// more efficiently.
    ///
    /// - parameter flags: Configuration flags for the temporary dispatch block
    public func callAndWait(flags: dispatch_block_flags_t = []) {
        DispatchBlock.cPerform(flags, block)
    }

    /// Wait synchronously until execution of the dispatch block has completed,
    /// or until the given timeout has elapsed.
    ///
    /// This function will return immediately if execution of the block has
    /// already completed.
    ///
    /// It is not possible to wait for multiple executions of the same block
    /// with this function; use a dispatch group for that purpose. A single
    /// dispatch block may either be waited on once and executed once, or it
    /// may be executed any number of times. The behavior of any other
    /// combination is undefined.
    ///
    /// Submission to a dispatch queue counts as an execution, even if a
    /// cancellation means the block's code never runs.
    ///
    /// The result of calling this function from multiple threads simultaneously
    /// is undefined.
    ///
    /// If this function returns indicating that the timeout has elapsed, the
    /// one allowed wait has not been met.
    ///
    /// If at the time this function is called, the dispatch block has been
    /// submitted directly to a serial queue, the system will make a best effort
    /// to apply necessary overrides to ensure that the blocks on the serial
    /// queue are executed at the QOS class or higher of the calling queue.
    ///
    /// - parameter timeout: When to timeout.
    /// - seealso: Timeout
    /// - seealso: dispatch_group_t
    public func waitUntilFinished(timeout: Timeout = .Forever) -> Bool {
        return DispatchBlock.cWait(block, timeout.rawValue) == 0
    }

    /// Schedule a notification handler to be submitted to a queue when the
    /// dispatch block has completed execution.
    ///
    /// The notification handler will be submitted immediately if execution of
    /// the dispatch block has already completed.
    ///
    /// It is not possible to be notifiied of multiple executions of the same
    /// block with this function; use a dispatch group for that purpose. A
    /// single dispatch block may either be waited on once and executed once, or
    /// it may be executed any number of times. The behavior of any other
    /// combination is undefined.
    ///
    /// Submission to a dispatch queue counts as an execution, even if a
    /// cancellation means the block's code never runs.
    ///
    /// If multiple notification handlers are scheduled for a single block,
    /// there is no defined order in which the handlers will be submitted to
    /// their associated queues.
    ///
    /// - parameter queue: The dispatch queue to which the `handler` will be
    ///   submitted when the observed block completes.
    /// - parameter flags: Configuration flags for the notification handler
    /// - parameter handler: The notification handler to submit when the
    ///   observed block completes.
    /// - returns: The derived dispatch block submitted for notification. Can
    ///   be used to cancel or wait.
    /// - seealso: dispatch_group_t
    public func upon(queue: dispatch_queue_t, flags: Flags, handler: dispatch_block_t) -> DispatchBlock {
        let block = DispatchBlock(flags: flags, body: handler)
        upon(queue, handler: block)
        return block
    }

    /// Schedule a notification handler to be submitted to a queue when the
    /// dispatch block has completed execution.
    ///
    /// The notification handler will be submitted immediately if execution of
    /// the dispatch block has already completed.
    ///
    /// It is not possible to be notifiied of multiple executions of the same
    /// block with this function; use a dispatch group for that purpose. A
    /// single dispatch block may either be waited on once and executed once, or
    /// it may be executed any number of times. The behavior of any other
    /// combination is undefined.
    ///
    /// Submission to a dispatch queue counts as an execution, even if a
    /// cancellation means the block's code never runs.
    ///
    /// If multiple notification handlers are scheduled for a single block,
    /// there is no defined order in which the handlers will be submitted to
    /// their associated queues.
    ///
    /// - parameter queue: The dispatch queue to which the `handler` will be
    ///   submitted when the observed block completes.
    /// - parameter handler: The notification handler to submit when the
    ///   observed block completes.
    /// - seealso: dispatch_group_t
    public func upon(queue: dispatch_queue_t, handler: DispatchBlock) {
        DispatchBlock.cNotify(block, queue, handler.block)
    }

    /// Asynchronously cancel the dispatch block.
    ///
    /// Cancellation causes any future execution of the dispatch block to
    /// return immediately, but does not affect any execution of the block
    /// that is already in progress.
    ///
    /// Release of any resources associated with the block will be delayed until
    /// until execution of the block is next attempted, or any execution already
    /// in progress completes.
    ///
    /// - warning: Care needs to be taken to ensure that a block that may be
    ///   cancelled does not capture any resources that require execution of the
    ///   block body in order to be released. Such resources will be leaked if
    ///   the block body is never executed due to cancellation.
    public func cancel() {
        DispatchBlock.cCancel(block)
    }

    /// Tests whether the dispatch block has been cancelled.
    public var isCancelled: Bool {
        return DispatchBlock.cTestCancel(block) != 0
    }

    /// Submits the block for asynchronous execution on a dispatch queue.
    ///
    /// Calls to submit a block always return immediately, and never wait for
    /// the block to be invoked.
    ///
    /// The queue determines whether the block will be invoked serially or
    /// concurrently with respect to other blocks submitted to that same queue.
    /// Serial queues are processed concurrently with respect to each other.
    ///
    /// - parameter queue: The target dispatch queue to which the block is submitted
    /// - seealso: dispatch_async(_:_:)
    public func callUponQueue(queue: dispatch_queue_t, afterDelay delay: NSTimeInterval = 0) {
        if delay <= 0 {
            DispatchBlock.cAsync(queue, block)
        } else {
            let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
            DispatchBlock.cAfter(time, queue, block)
        }
    }

    /// Submits a block for synchronous execution on a dispatch queue.
    ///
    /// Submits a block to a dispatch queue like `callUponQueue`, but will not
    /// return until the block has finished.
    ///
    /// Calls targeting the current queue will result in deadlock. Use is also
    /// subject to the same multi-party deadlock problems that may result from
    /// the use of a mutex. Use of `callUponQueue` is preferred.
    ///
    /// - parameter queue: The target dispatch queue to which the block is submitted
    /// - seealso: dispatch_sync(_:_:)
    public func callUponQueueAndWait(queue: dispatch_queue_t) {
        DispatchBlock.cSync(queue, block)
    }

    /// Enqueues a dispatch block on a given runloop to be executed as the
    /// runloop cycles next.
    public func callInRunLoop(runLoop: NSRunLoop) {
        CFRunLoopPerformBlock(runLoop.getCFRunLoop(), NSRunLoopCommonModes, block)
    }

}

extension DispatchBlock: CustomStringConvertible, CustomReflectable, CustomPlaygroundQuickLookable {

    /// A textual representation of `self`.
    public var description: String {
        return String(block)
    }

    /// Return the `Mirror` for `self`.
    public func customMirror() -> Mirror {
        return Mirror(reflecting: block)
    }

    /// Return the `PlaygroundQuickLook` for `self`.
    public func customPlaygroundQuickLook() -> PlaygroundQuickLook {
        return .Text("() -> ()")
    }

}

// MARK: - Compatibility aliases

/// Submits the block for asynchronous execution on a dispatch queue.
///
/// The `dispatch_async` function is the fundamental mechanism for submitting
/// blocks to a dispatch queue.
///
/// Calls to submit a block always return immediately, and never wait for
/// the block to be invoked.
///
/// The queue determines whether the block will be invoked serially or
/// concurrently with respect to other blocks submitted to that same queue.
/// Serial queues are processed concurrently with respect to each other.
///
/// - parameter queue: The target dispatch queue to which the block is submitted
public func dispatch_async(queue: dispatch_queue_t, _ block: DispatchBlock) {
    block.callUponQueue(queue)
}

/// Submits a block for synchronous execution on a dispatch queue.
///
/// Submits a block to a dispatch queue like `dispatch_async`, but will not
/// return until the block has finished.
///
/// Calls targeting the current queue will result in deadlock. Use is also
/// subject to the same multi-party deadlock problems that may result from
/// the use of a mutex. Use of `dispatch_async` is preferred.
///
/// - parameter queue: The target dispatch queue to which the block is submitted
public func dispatch_sync(queue: dispatch_queue_t, _ block: DispatchBlock) {
    block.callUponQueueAndWait(queue)
}
