//
//  TWLUtilities.m
//  Tomorrowland
//
//  Created by Kevin Ballard on 1/5/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLUtilities.h"
#import "TWLPromisePrivate.h"
#import "TWLContextPrivate.h"

@implementation TWLPromise (Utilities)

- (TWLPromise *)delay:(NSTimeInterval)delay {
    return [self delay:delay onContext:TWLContext.automatic];
}

- (TWLPromise *)delay:(NSTimeInterval)delay onContext:(TWLContext *)context {
    TWLResolver *resolver;
    TWLPromise *promise = [[TWLPromise alloc] initWithResolver:&resolver];
    dispatch_queue_t queue = [context getQueue];
    [self enqueueCallback:^(id _Nullable value, id _Nullable error) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * (NSTimeInterval)NSEC_PER_SEC)), queue, ^{
            [resolver resolveWithValue:value error:error];
        });
    } willPropagateCancel:YES];
    __weak TWLObjCPromiseBox *box = _box;
    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
        [box propagateCancel];
    }];
    return promise;
}

- (TWLPromise *)timeoutWithDelay:(NSTimeInterval)delay {
    return [self timeoutOnContext:TWLContext.automatic withDelay:delay cancelOnTimeout:YES];
}

- (TWLPromise *)timeoutOnContext:(TWLContext *)context withDelay:(NSTimeInterval)delay {
    return [self timeoutOnContext:context withDelay:delay cancelOnTimeout:YES];
}

- (TWLPromise *)timeoutOnContext:(TWLContext *)context withDelay:(NSTimeInterval)delay cancelOnTimeout:(BOOL)cancelOnTimeout {
    TWLResolver *resolver;
    TWLPromise *promise = [[TWLPromise alloc] initWithResolver:&resolver];
    __weak TWLObjCPromiseBox *weakBox = _box;
    __weak TWLObjCPromiseBox *weakNewBox = promise->_box;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        TWLObjCPromiseBox *newBox = weakNewBox;
        if (newBox) {
            TWLResolver *resolver = [[TWLResolver alloc] initWithBox:newBox];
            // double-check the result just in case
            id value;
            id error;
            if ([weakBox getValue:&value error:&error]) {
                if (error) {
                    error = [TWLTimeoutError newWithRejectedError:error];
                }
                [resolver resolveWithValue:value error:error];
            } else {
                [resolver rejectWithError:[TWLTimeoutError newTimedOut]];
            }
        }
        if (cancelOnTimeout) {
            [weakBox requestCancel];
        }
    });
    [self enqueueCallback:^(id _Nullable value, id _Nullable error) {
        dispatch_block_cancel(timeoutBlock);
        if (error) {
            error = [TWLTimeoutError newWithRejectedError:error];
        }
        [context executeBlock:^{
            [resolver resolveWithValue:value error:error];
        }];
    } willPropagateCancel:YES];
    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
        [weakBox propagateCancel];
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * (NSTimeInterval)NSEC_PER_SEC)), [context getQueue], timeoutBlock);
    return promise;
}

@end

@implementation TWLTimeoutError

+ (instancetype)newTimedOut {
    return [[self alloc] initTimedOut];
}

+ (instancetype)newWithRejectedError:(id)error {
    return [[self alloc] initWithRejectedError:error];
}

- (instancetype)initTimedOut {
    if ((self = [super init])) {
        _timedOut = YES;
    }
    return self;
}

- (instancetype)initWithRejectedError:(id)error {
    if ((self = [super init])) {
        _rejectedError = error;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[TWLTimeoutError class]]) return NO;
    TWLTimeoutError *other = object;
    if (self.timedOut) {
        return other.timedOut;
    } else {
        return [self.rejectedError isEqual:other.rejectedError];
    }
}

- (NSUInteger)hash {
    if (self.timedOut) {
        return 1;
    } else {
        return [self.rejectedError hash] << 1;
    }
}

@end
