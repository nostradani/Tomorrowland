//
//  DeinitSpy.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 4/5/19.
//  Copyright © 2019 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest

/// A class that runs a block when deinited.
class DeinitSpy {
    let onDeinit: () -> Void
    
    init(onDeinit: @escaping () -> Void) {
        self.onDeinit = onDeinit
    }
    
    convenience init(fulfilling expectation: XCTestExpectation) {
        self.init(onDeinit: { expectation.fulfill() })
    }
    
    deinit {
        onDeinit()
    }
}
