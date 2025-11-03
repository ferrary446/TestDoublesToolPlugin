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
    func createBuildCommand(for inputPath: URL, in outputDirectoryPath: URL, with generatorToolPath: URL, context: Any) throws -> Command? {
        // Check if the file contains TestDoubles annotations
        guard inputPath.pathExtension == "swift" else { return nil }
        
        let fileContent = try String(contentsOf: inputPath, encoding: .utf8)
        guard fileContent.contains("// TestDoubles:") else { return nil }
        
        // Return a command that will run during the build to generate the output files.
        let inputName = inputPath.lastPathComponent
        return .buildCommand(
            displayName: "Generating test doubles from \(inputName)",
            executable: generatorToolPath,
            arguments: ["\(inputPath.path)", "-o", "\(outputDirectoryPath.path)"],
            inputFiles: [inputPath],
            outputFiles: [] // Output files are dynamically generated, so we can't predict them here
        )
    }
}
