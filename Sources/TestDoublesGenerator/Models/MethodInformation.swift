//
//  MethodInformation.swift
//  TestDoublesToolPlugin
//
//  Created by Ilya Yushkov on 03.11.2025.
//

import Foundation

struct MethodInformation {
    let name: String
    let parameters: [ParameterInformation]
    let returnType: String?
    let isAsync: Bool
    let isThrows: Bool
}
