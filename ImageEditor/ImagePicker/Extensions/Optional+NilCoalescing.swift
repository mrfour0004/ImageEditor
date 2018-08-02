//
//  Optional+NilCoalescing.swift
//  Snapask
//
//  Created by mrfour on 2018/7/6.
//  Copyright © 2018 mrfour. All rights reserved.
//

import Foundation

extension Optional {
    /// A convenience function to replace the offical nil-coalescing operator due the compile time.
    ///
    /// ## Example
    /// ```
    /// // preferred
    /// let int: Int = optionalInt.or(0)
    ///
    /// // not preferred
    /// let int: Int = optionalInt ?? 0
    ///
    /// ```
    ///
    /// - Parameter defaultValue: The value to be returned when wrapped value is `nil`.
    /// - Returns: The wrapped value or the given default value when the wrapped value is `nil`.
    func or(_ defaultValue: Wrapped) -> Wrapped {
        switch self {
        case .none:
            return defaultValue
        case .some(let value):
            return value
        }
    }
}
