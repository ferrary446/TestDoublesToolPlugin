//
//  TestDoublesToolPlugin.swift
//  TestDoublesToolPlugin
//
//  Created by Ilya Yushkov on 03.11.2025.
//

import Foundation
import PackagePlugin

@main
struct TestDoublesToolPlugin: BuildToolPlugin {
    /// Entry point for creating build commands for targets in Swift packages.
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // This plugin only runs for package targets that can have source files.
        guard let sourceFiles = target.sourceModule?.sourceFiles else { return [] }

        // Find the code generator tool to run.
        let generatorTool = try context.tool(named: "TestDoublesGenerator")

        // Only process Swift files that contain TestDoubles annotations
        let swiftFiles = sourceFiles.filter { $0.url.pathExtension == "swift" }
        var commands: [Command] = []
        
        for sourceFile in swiftFiles {
            if let command = try createBuildCommand(for: sourceFile.url, in: context.pluginWorkDirectoryURL, with: generatorTool.url, context: context) {
                commands.append(command)
            }
        }
        
        return commands
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension TestDoublesToolPlugin: XcodeBuildToolPlugin {
    // Entry point for creating build commands for targets in Xcode projects.
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        // Find the code generator tool to run.
        let generatorTool = try context.tool(named: "TestDoublesGenerator")

        // Only process Swift files that contain TestDoubles annotations
        let swiftFiles = target.inputFiles.filter { $0.url.pathExtension == "swift" }
        var commands: [Command] = []
        
        for inputFile in swiftFiles {
            if let command = try createBuildCommand(for: inputFile.url, in: context.pluginWorkDirectoryURL, with: generatorTool.url, context: context) {
                commands.append(command)
            }
        }
        
        return commands
    }
}

#endif

extension TestDoublesToolPlugin {
    /// Shared function that returns a configured build command if the input files should be processed.
    func createBuildCommand(
        for inputPath: URL,
        in outputDirectoryPath: URL,
        with generatorToolPath: URL,
        context: Any
    ) throws -> Command? {
        guard inputPath.pathExtension == "swift" else { return nil }

        let content = try String(contentsOf: inputPath, encoding: .utf8)
        guard content.contains("// TestDoubles:") else { return nil }

        let outDir = outputDirectoryPath.appendingPathComponent("DerivedSources", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let outputs = inferOutputs(from: content, outputDir: outDir)
        guard !outputs.isEmpty else { return nil }

        return .buildCommand(
            displayName: "Generating test doubles from \(inputPath.lastPathComponent)",
            executable: generatorToolPath,
            arguments: [inputPath.path, "-o", outDir.path],
            inputFiles: [inputPath],
            outputFiles: outputs
        )
    }

    private func inferOutputs(from source: String, outputDir: URL) -> [URL] {
        var outputs: [URL] = []

        func nextName(after marker: String, regex: String) -> String? {
            guard let range = source.range(of: marker) else { return nil }

            let tail = String(source[range.upperBound...])
            let pattern = try! NSRegularExpression(pattern: regex)

            if let match = pattern.firstMatch(in: tail, range: NSRange(tail.startIndex..., in: tail)), let r = Range(match.range(at: 1), in: tail) {
                return String(tail[r])
            }

            return nil
        }

        if let name = nextName(after: "// TestDoubles:spy", regex: #"protocol\s+(\w+)"#) {
            outputs.append(outputDir.appendingPathComponent("\(name)Spy.swift"))
        }

        if let name = nextName(after: "// TestDoubles:mock", regex: #"protocol\s+(\w+)"#) {
            outputs.append(outputDir.appendingPathComponent("\(name)Mock.swift"))
        }

        if let name = nextName(after: "// TestDoubles:struct", regex: #"struct\s+(\w+)"#) {
            outputs.append(outputDir.appendingPathComponent("\(name)+Mock.swift"))
        }

        return outputs
    }
}
