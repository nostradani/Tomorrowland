//
//  UtilityTests.swift
//  PromissoryTests
//
//  Created by Ballard, Kevin on 12/21/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

import XCTest
import Promissory

final class UtilityTests: XCTestCase {
    func testDelayFulfill() {
        // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(42)
        }).delay(on: .utility, 0.05)
        let expectation = XCTestExpectation(description: "promise")
        var invoked: DispatchTime?
        promise.always(on: .userInteractive, { (result) in
            invoked = .now()
            XCTAssertEqual(result, .value(42))
            expectation.fulfill()
        })
        let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(50)
        sema.signal()
        wait(for: [expectation], timeout: 1)
        if let invoked = invoked {
            XCTAssert(invoked > deadline)
        } else {
            XCTFail("Didn't retrieve invoked value")
        }
    }
    
    func testDelayReject() {
        // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.reject("foo")
        }).delay(on: .utility, 0.05)
        let expectation = XCTestExpectation(description: "promise")
        var invoked: DispatchTime?
        promise.always(on: .userInteractive, { (result) in
            invoked = .now()
            XCTAssertEqual(result, .error("foo"))
            expectation.fulfill()
        })
        let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(50)
        sema.signal()
        wait(for: [expectation], timeout: 1)
        if let invoked = invoked {
            XCTAssert(invoked > deadline)
        } else {
            XCTFail("Didn't retrieve invoked value")
        }
    }
    
    func testDelayCancel() {
        // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.cancel()
        }).delay(on: .utility, 0.05)
        let expectation = XCTestExpectation(description: "promise")
        var invoked: DispatchTime?
        promise.always(on: .userInteractive, { (result) in
            invoked = .now()
            XCTAssertEqual(result, .cancelled)
            expectation.fulfill()
        })
        let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(50)
        sema.signal()
        wait(for: [expectation], timeout: 1)
        if let invoked = invoked {
            XCTAssert(invoked > deadline)
        } else {
            XCTFail("Didn't retrieve invoked value")
        }
    }
}
