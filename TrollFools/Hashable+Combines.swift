//
//  Hashable+Combines.swift
//  TrollFools
//
//  Created by 82Flex on 3/9/25.
//

import Foundation

func combines(_ value: any Hashable ...) -> Int {
    var hasher = Hasher()
    for v in value {
        hasher.combine(v)
    }
    return hasher.finalize()
}
