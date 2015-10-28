//
//  DispatchDeferred.h
//  Deferred
//
//  Created by Zachary Waldowski on 7/28/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern dispatch_queue_t deferred_create_queue(_Nullable id storage, _Nonnull id *_Nonnull outOnFilledToken);
extern _Bool deferred_is_filled(id onFilledToken);

extern void deferred_queue_fill(dispatch_queue_t queue, id onFilledToken, id storage, void(^_Nullable ifAlreadyFilled)(void));
extern void deferred_queue_upon(dispatch_queue_t queue, id onFilledToken, void(^accessHandler)(id storage));
extern _Bool deferred_queue_wait(dispatch_queue_t queue, id onFilledToken, dispatch_time_t when, __attribute__((noescape)) void(^accessHandler)(id storage));

NS_ASSUME_NONNULL_END
