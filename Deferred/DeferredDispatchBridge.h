//
//  DeferredDispatchBridge.h
//  Deferred
//
//  Created by Zachary Waldowski on 7/28/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const void *DeferredStorageKey;

extern dispatch_queue_t deferred_queue_create(id object, BOOL isFilled);
extern BOOL deferred_queue_is_filled(dispatch_queue_t queue);
void deferred_queue_notify(dispatch_queue_t queue, dispatch_block_t block);

extern void deferred_mark_filled(void);
extern void deferred_upon(dispatch_queue_t queue, dispatch_block_t block);
BOOL deferred_wait(dispatch_queue_t queue, dispatch_time_t when, __attribute__((noescape)) dispatch_block_t block);

NS_ASSUME_NONNULL_END
