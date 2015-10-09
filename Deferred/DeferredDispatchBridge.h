//
//  DeferredDispatchBridge.h
//  Deferred
//
//  Created by Zachary Waldowski on 7/28/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_INLINE void deferred_queue_set_specific_object(dispatch_queue_t queue, const void *key, id object) {
    dispatch_queue_set_specific(queue, key, (void *)CFBridgingRetain(object), (dispatch_function_t)CFBridgingRelease);
}

NS_ASSUME_NONNULL_END
