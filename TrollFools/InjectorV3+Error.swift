//
//  InjectorV3+Error.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import Foundation

extension InjectorV3 {

    enum Error: LocalizedError {
        case generic(String)

        var errorDescription: String? {
            switch self {
            case .generic(let reason): reason
            }
        }
    }
}
