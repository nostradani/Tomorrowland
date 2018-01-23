//
//  TWLCancelTests.m
//  TomorrowlandTests
//
//  Created by Ballard, Kevin on 1/21/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+TWLPromise.h"
@import Tomorrowland;

@interface TWLCancelTests : XCTestCase

@end

@implementation TWLCancelTests

- (void)testRequestCancelOnInvalidate {
    dispatch_semaphore_t sema;
    TWLPromise *promise = makeCancellablePromiseWithValue(@2, &sema);
    TWLInvalidationToken *token = [TWLInvalidationToken new];
    [token requestCancelOnInvalidate:promise];
    XCTestExpectation *expectation = [self expectationOnCancel:promise];
    [token invalidate];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testRequestCancelOnInvalidateMultipleBlocks {
    TWLInvalidationToken *token = [TWLInvalidationToken new];
    NSMutableArray<XCTestExpectation*> *expectations = [NSMutableArray new];
    NSMutableArray<dispatch_semaphore_t> *semas = [NSMutableArray array];
    for (NSUInteger i = 0; i < 5; ++i) {
        dispatch_semaphore_t sema;
        TWLPromise *promise = makeCancellablePromiseWithValue(@2, &sema);
        [token requestCancelOnInvalidate:promise];
        [expectations addObject:[self expectationOnCancel:promise]];
        [semas addObject:sema];
    }
    [token invalidate];
    for (dispatch_semaphore_t sema in semas) {
        dispatch_semaphore_signal(sema);
    }
    [self waitForExpectations:expectations timeout:1];
}

- (void)testPropagateCancelThen {
    NSArray<XCTestExpectation*> *expectations;
    dispatch_semaphore_t sema;
    {
        TWLPromise *promise = makeCancellablePromiseWithError(@"foo", &sema);
        TWLPromise *promise2 = [promise thenOnContext:TWLContext.utility handler:^(id _Nonnull value) {
            XCTFail(@"callback invoked");
        }];
        expectations = @[[self expectationOnCancel:promise],
                         [self expectationOnCancel:promise2]];
        [promise2 requestCancel];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testPropagateCancelThenCancelAfterSeal {
    // Ensure cancelling after the promise is sealed works as well.
    // We're just going to test it on this one type instead of on all.
    NSArray<XCTestExpectation*> *expectations;
    dispatch_semaphore_t sema;
    TWLPromise *promise2;
    {
        TWLPromise *promise = makeCancellablePromiseWithError(@"foo", &sema);
        promise2 = [promise thenOnContext:TWLContext.utility handler:^(id _Nonnull value) {
            XCTFail(@"callback invoked");
        }];
        expectations = @[[self expectationOnCancel:promise],
                         [self expectationOnCancel:promise2]];
    }
    [promise2 requestCancel];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testPropagateCnacelThenDontCancelIfMoreObservers {
    NSArray<XCTestExpectation*> *expectations;
    dispatch_semaphore_t sema;
    TWLPromise *promise2;
    {
        TWLPromise *promise = makeCancellablePromiseWithError(@"foo", &sema);
        promise2 = [promise thenOnContext:TWLContext.utility handler:^(id _Nonnull value) {
            XCTFail("callback invoked");
        }];
        TWLPromise *promise3 = [promise thenOnContext:TWLContext.utility handler:^(id _Nonnull value) {
            XCTFail("callback invoked");
        }];
        // Note: promise2 isn't cancelled here because requestCancel on a registered callback
        // promise doesn't actually cancel it, it just propagates the cancel request upwards. The
        // promise is only cancelled if its parent promise is cancelled.
        expectations = @[[self expectationOnError:promise expectedError:@"foo"],
                         [self expectationOnError:promise2 expectedError:@"foo"],
                         [self expectationOnError:promise3 expectedError:@"foo"]];
    }
    [promise2 requestCancel];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testPropagateCancelThenCancelAfterAllObservers {
    NSArray<XCTestExpectation*> *expectations;
    dispatch_semaphore_t sema;
    TWLPromise *promise2, *promise3;
    {
        TWLPromise *promise = makeCancellablePromiseWithError(@"foo", &sema);
        promise2 = [promise thenOnContext:TWLContext.utility handler:^(id _Nonnull value) {
            XCTFail("callback invoked");
        }];
        promise3 = [promise thenOnContext:TWLContext.utility handler:^(id _Nonnull value) {
            XCTFail("callback invoked");
        }];
        expectations = @[[self expectationOnCancel:promise],
                         [self expectationOnCancel:promise2],
                         [self expectationOnCancel:promise3]];
    }
    [promise2 requestCancel];
    // if promise cancelled then it should have propagated to promise3 already
    XCTAssertFalse([promise3 getValue:NULL error:NULL]);
    [promise3 requestCancel];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testPropgateCancelNoCancelWithNoObservers {
    XCTestExpectation *expectation;
    dispatch_semaphore_t sema;
    {
        TWLPromise *promise = makeCancellablePromiseWithError(@"foo", &sema);
        expectation = [self expectationOnError:promise expectedError:@"foo"];
    }
    // promise has gone away, but won't have cancelled
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testPropagateCancelMap {
    NSArray<XCTestExpectation*> *expectations;
    dispatch_semaphore_t sema;
    {
        TWLPromise *promise = makeCancellablePromiseWithError(@"foo", &sema);
        TWLPromise *promise2 = [promise mapOnContext:TWLContext.utility handler:^id(id _Nonnull value) {
            XCTFail(@"callback invoked");
            return @42;
        }];
        expectations = @[[self expectationOnCancel:promise],
                         [self expectationOnCancel:promise2]];
        [promise2 requestCancel];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testPropagateCancelCatch {
    NSArray<XCTestExpectation*> *expectations;
    dispatch_semaphore_t sema;
    {
        TWLPromise *promise = makeCancellablePromiseWithError(@"foo", &sema);
        TWLPromise *promise2 = [promise catchOnContext:TWLContext.utility handler:^(id _Nonnull error) {
            XCTFail(@"callback invoked");
        }];
        expectations = @[[self expectationOnCancel:promise],
                         [self expectationOnCancel:promise2]];
        [promise2 requestCancel];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testPropagateCancelRecover {
    NSArray<XCTestExpectation*> *expectations;
    dispatch_semaphore_t sema;
    {
        TWLPromise *promise = makeCancellablePromiseWithError(@"foo", &sema);
        TWLPromise *promise2 = [promise recoverOnContext:TWLContext.utility handler:^id(id _Nonnull error) {
            XCTFail(@"callback invoked");
            return @42;
        }];
        expectations = @[[self expectationOnCancel:promise],
                         [self expectationOnCancel:promise2]];
        [promise2 requestCancel];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testPropagateCancelInspect {
    NSArray<XCTestExpectation*> *expectations;
    dispatch_semaphore_t sema;
    {
        TWLPromise *promise = makeCancellablePromiseWithError(@"foo", &sema);
        TWLPromise *promise2 = [promise inspectOnContext:TWLContext.utility handler:^(id _Nullable value, id _Nullable error) {
            XCTAssertNil(value);
            XCTAssertNil(error);
        }];
        expectations = @[[self expectationOnCancel:promise],
                         [self expectationOnCancel:promise2]];
        [promise2 requestCancel];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testPropagateCancelAlways {
    NSArray<XCTestExpectation*> *expectations;
    dispatch_semaphore_t sema;
    {
        TWLPromise *promise = makeCancellablePromiseWithError(@"foo", &sema);
        TWLPromise *promise2 = [promise alwaysOnContext:TWLContext.utility handler:^TWLPromise * _Nonnull (id _Nullable value, id _Nullable error) {
            XCTAssertNil(value);
            XCTAssertNil(error);
            return [TWLPromise newFulfilledWithValue:@42];
        }];
        expectations = @[[self expectationOnCancel:promise],
                         [self expectationOnSuccess:promise2 expectedValue:@42]];
        [promise2 requestCancel];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testPropagateCancelWhenCancelled {
    NSArray<XCTestExpectation*> *expectations;
    dispatch_semaphore_t sema;
    {
        TWLPromise *promise = makeCancellablePromiseWithError(@"foo", &sema);
        XCTestExpectation *cancelExpectation = [[XCTestExpectation alloc] initWithDescription:@"whenCancelRequested"];
        TWLPromise *promise2 = [promise whenCancelledOnContext:TWLContext.utility handler:^{
            [cancelExpectation fulfill];
        }];
        expectations = @[[self expectationOnCancel:promise],
                         [self expectationOnCancel:promise2],
                         cancelExpectation];
        [promise2 requestCancel];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testPropagateCancelDelayedPromise {
    NSArray<XCTestExpectation*> *expectations;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    {
        TWLDelayedPromise *delayedPromise = [TWLDelayedPromise newOnContext:TWLContext.utility handler:^(TWLResolver * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
                [resolver cancel];
            }];
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver rejectWithError:@"foo"];
        }];
        TWLPromise *promise2 = [delayedPromise.promise thenOnContext:TWLContext.utility handler:^(id _Nonnull value) {
            XCTFail(@"Callback invoked");
        }];
        expectations = @[[self expectationOnCancel:delayedPromise.promise],
                         [self expectationOnCancel:promise2]];
        [promise2 requestCancel];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

static TWLPromise * _Nonnull makeCancellablePromiseWithValue(id _Nonnull value, dispatch_semaphore_t _Nullable * _Nonnull outSema) {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise *promise = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
            [resolver cancel];
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:value];
    }];
    *outSema = sema;
    return promise;
}

static TWLPromise * _Nonnull makeCancellablePromiseWithError(id _Nonnull error, dispatch_semaphore_t _Nullable * _Nonnull outSema) {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise *promise = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
            [resolver cancel];
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver rejectWithError:error];
    }];
    *outSema = sema;
    return promise;
}

@end