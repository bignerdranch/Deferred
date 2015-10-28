//
//  DispatchDeferred.m
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2015 Big Nerd Ranch. All rights reserved.
//

#import "DispatchDeferred.h"
#import <Foundation/Foundation.h>

/** Due to limitations in Swift 2.0 Beta 6, the `dispatch_block_*` APIs must be
 used from Objective-C. In a future version of Swift, this code can and should
 all be moved into Deferred itself.
**/

const void *DeferredStorageKey = &DeferredStorageKey;
static const void *DeferredOnFilledBlockKey = &DeferredOnFilledBlockKey;

OS_OVERLOADABLE OS_INLINE dispatch_block_t onFilledToken(void) {
    return (__bridge dispatch_block_t)dispatch_get_specific(DeferredOnFilledBlockKey);
}

OS_OVERLOADABLE OS_INLINE dispatch_block_t onFilledToken(dispatch_queue_t queue) {
    return (__bridge dispatch_block_t)dispatch_queue_get_specific(queue, DeferredOnFilledBlockKey);
}

OS_INLINE void deferred_block_mark_filled(dispatch_block_t onFilled) {
    dispatch_block_cancel(onFilled);
    onFilled();
}

dispatch_queue_t deferred_queue_create(id object, BOOL isFilled) {
    dispatch_queue_t queue = dispatch_queue_create("Deferred", DISPATCH_QUEUE_CONCURRENT);
    dispatch_block_t block = dispatch_block_create(0, ^{});

    dispatch_queue_set_specific(queue, DeferredOnFilledBlockKey, (void *)CFBridgingRetain(block), (dispatch_function_t)CFBridgingRelease);
    dispatch_queue_set_specific(queue, DeferredStorageKey, (void *)CFBridgingRetain(object), (dispatch_function_t)CFBridgingRelease);

    if (isFilled) {
        deferred_block_mark_filled(block);
    }

    return queue;
}

void deferred_mark_filled() {
    deferred_block_mark_filled(onFilledToken());
}

BOOL deferred_queue_is_filled(dispatch_queue_t queue) {
    return dispatch_block_testcancel(onFilledToken(queue));
}

void deferred_upon(dispatch_queue_t queue, dispatch_block_t block) {
    dispatch_block_notify(onFilledToken(), queue, block);
}

BOOL deferred_wait(dispatch_queue_t queue, dispatch_time_t when, __attribute__((noescape)) dispatch_block_t inBlock) {
    dispatch_block_t block = dispatch_block_create(DISPATCH_BLOCK_ASSIGN_CURRENT|DISPATCH_BLOCK_ENFORCE_QOS_CLASS, inBlock);
    dispatch_block_notify(onFilledToken(queue), queue, block);
    if (dispatch_block_wait(block, when) != noErr) {
        dispatch_block_cancel(block);
        return NO;
    }
    return YES;
}
