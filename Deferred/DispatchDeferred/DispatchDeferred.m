//
//  DispatchDeferred.m
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2015 Big Nerd Ranch. All rights reserved.
//

#import "DispatchDeferred.h"
#import <Foundation/Foundation.h>

/** Due to limitations in Swift 2.0, the `dispatch_block_*` APIs must be used
 from Objective-C. In Swift 2.1, this code can and should be moved into Deferred
 itself.
**/

static const void *DeferredStorageKey = &DeferredStorageKey;

OS_INLINE void deferred_fill_locked(dispatch_queue_t queue, dispatch_block_t onFilled, id storage) {
    dispatch_queue_set_specific(queue, DeferredStorageKey, (void *)CFBridgingRetain(storage), (dispatch_function_t)CFBridgingRelease);
    dispatch_block_cancel(onFilled);
    onFilled();
}

OS_INLINE dispatch_block_t deferred_upon_block(dispatch_block_flags_t flags, void(^accessHandler)(id)) {
    return dispatch_block_create(flags, ^{
        void *storage = dispatch_get_specific(DeferredStorageKey);
        if (storage == NULL) { return; };
        accessHandler((__bridge id)storage);
    });
}

dispatch_queue_t deferred_create_queue(_Nullable id storage, _Nonnull id *_Nonnull outOnFilledToken) {
    dispatch_queue_t queue = dispatch_queue_create("Deferred", DISPATCH_QUEUE_CONCURRENT);
    dispatch_block_t block = dispatch_block_create(0, ^{});

    if (storage != nil) {
        deferred_fill_locked(queue, block, storage);
    }

    *outOnFilledToken = block;
    return queue;
}

_Bool deferred_is_filled(id token) {
    return dispatch_block_testcancel(token) != 0;
}

void deferred_queue_fill(dispatch_queue_t queue, id onFilledToken, id storage, void(^ifAlreadyFilled)(void)) {
    dispatch_barrier_async(queue, ^{
        if (dispatch_get_specific(DeferredStorageKey) == NULL) {
            deferred_fill_locked(queue, onFilledToken, storage);
        } else if (ifAlreadyFilled != NULL) {
            ifAlreadyFilled();
        }
    });
}

void deferred_queue_upon(dispatch_queue_t queue, id onFilledToken, void(^accessHandler)(id)) {
    dispatch_block_notify(onFilledToken, queue, deferred_upon_block(0, accessHandler));
}

_Bool deferred_queue_wait(dispatch_queue_t queue, id token, dispatch_time_t when, __attribute__((noescape)) void(^accessHandler)(id storage)) {
    dispatch_block_t block = deferred_upon_block(DISPATCH_BLOCK_ASSIGN_CURRENT|DISPATCH_BLOCK_ENFORCE_QOS_CLASS, accessHandler);
    dispatch_block_notify(token, queue, block);
    if (dispatch_block_wait(block, when) != noErr) {
        dispatch_block_cancel(block);
        return false;
    }
    return true;
}
