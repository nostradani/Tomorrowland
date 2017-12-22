//
//  Utilities.swift
//  Promissory
//
//  Created by Ballard, Kevin on 12/21/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

import Dispatch
import struct Foundation.TimeInterval

extension Promise {
    /// Returns a new `Promise` that adopts the receiver's result after a delay.
    ///
    /// - Parameter context: The context to resolve the new `Promise` on. This is generally only
    ///   important when using callbacks registered with `.immediate`. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    ///   If provided as `.immediate`, behaves the same as `.auto`. If provided as `.operationQueue`
    ///   it uses the `OperationQueue`'s underlying queue, or `.default` if there is no underlying
    ///   queue.
    /// - Parameter delay: The number of seconds to delay the resulting promise by.
    /// - Returns: A `Promise` that adopts the same result as the receiver after a delay.
    public func delay(on context: PromiseContext = .auto, _ delay: TimeInterval) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _box.enqueue { (result) in
            context.getQueue().asyncAfter(deadline: .now() + delay) {
                switch result {
                case .value(let value): resolver.fulfill(value)
                case .error(let error): resolver.reject(error)
                case .cancelled: resolver.cancel()
                }
            }
        }
        return promise
    }
}
