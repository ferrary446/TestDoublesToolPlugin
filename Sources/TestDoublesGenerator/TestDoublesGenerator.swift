//
//  TestDoublesGenerator.swift
//  TestDoublesToolPlugin
//
//  Created by Ilya Yushkov on 03.11.2025.
//

import Foundation

@main
struct TestDoublesGenerator {
    static func main() async throws {
        let arguments = CommandLine.arguments

        guard arguments.count >= 3 else {
            print("Usage: TestDoublesGenerator <input-file> -o <output-directory>")
            exit(1)
        }

        let inputFilePath = arguments[1]
        let outputDirectory = arguments[3]

        let generator = CodeGenerator(
            inputFilePath: inputFilePath,
            outputDirectory: outputDirectory
        )

        try await generator.generate()
    }
}
