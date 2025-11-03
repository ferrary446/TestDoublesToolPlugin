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
        guard let sourceModule = target.sourceModule else { return [] }

        // Find the code generator tool to run.
        let generatorTool = try context.tool(named: "TestDoublesGenerator")

        var commands: [Command] = []
        var processedFiles = Set<URL>()
        
        // Automatically scan all source directories for TestDoubles annotations
        let sourceDirectories = [sourceModule.directoryURL]
        
        for directory in sourceDirectories {
            let testDoublesFiles = try scanForTestDoublesFiles(in: directory)
            
            for sourceFile in testDoublesFiles {
                // Skip if already processed to avoid duplicates
                if processedFiles.contains(sourceFile) {
                    continue
                }
                processedFiles.insert(sourceFile)
                
                if let command = try createBuildCommand(
                    for: sourceFile, 
                    in: context.pluginWorkDirectoryURL, 
                    with: generatorTool.url, 
                    context: context
                ) {
                    commands.append(command)
                }
            }
        }
        
        print("TestDoublesToolPlugin: Found \(commands.count) files with TestDoubles annotations")
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

        var commands: [Command] = []
        var processedFiles = Set<URL>()
        
        // Get all unique directories from input files
        let sourceDirectories = Set(target.inputFiles.map { $0.url.deletingLastPathComponent() })
        
        // Scan each directory for TestDoubles annotations
        for directory in sourceDirectories {
            let testDoublesFiles = try scanForTestDoublesFiles(in: directory)
            
            for sourceFile in testDoublesFiles {
                // Skip if already processed to avoid duplicates
                if processedFiles.contains(sourceFile) {
                    continue
                }
                processedFiles.insert(sourceFile)
                
                if let command = try createBuildCommand(
                    for: sourceFile, 
                    in: context.pluginWorkDirectoryURL, 
                    with: generatorTool.url, 
                    context: context
                ) {
                    commands.append(command)
                }
            }
        }
        
        print("TestDoublesToolPlugin: Found \(commands.count) files with TestDoubles annotations")
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
        
        // Create organized output directory structure
        let outputDir = createOutputDirectory(for: inputPath, in: outputDirectoryPath)
        
        // Ensure the output directory exists
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
        
        // Generate predictable output file names based on input
        let outputFiles = generateOutputFiles(for: inputPath, in: outputDir)
        
        // Return a command that will run during the build to generate the output files.
        let inputName = inputPath.lastPathComponent
        return .buildCommand(
            displayName: "Generating test doubles from \(inputName)",
            executable: generatorToolPath,
            arguments: [
                inputPath.path,
                "-o", outputDir.path,
                "--input-name", inputPath.deletingPathExtension().lastPathComponent
            ],
            inputFiles: [inputPath],
            outputFiles: outputFiles.map(\.url)
        )
    }
    
    /// Creates an organized output directory structure
    private func createOutputDirectory(for inputPath: URL, in baseOutputPath: URL) -> URL {
        // Create a unique subdirectory based on the full relative path from source
        let fileName = inputPath.deletingPathExtension().lastPathComponent
        
        // Use a more unique path structure to avoid collisions
        let uniquePath = inputPath.path.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        
        return baseOutputPath
            .appendingPathComponent("TestDoubles")
            .appendingPathComponent("\(fileName)_\(uniquePath.hash)")
    }
    
    /// Generates predictable output file paths
    private func generateOutputFiles(for inputPath: URL, in outputDir: URL) -> [(url: URL, type: String)] {
        let baseName = inputPath.deletingPathExtension().lastPathComponent
        
        return [
            (url: outputDir.appendingPathComponent("\(baseName)Mock.swift"), type: "mock"),
            (url: outputDir.appendingPathComponent("\(baseName)Stub.swift"), type: "stub"),
            (url: outputDir.appendingPathComponent("\(baseName)Spy.swift"), type: "spy")
        ]
    }
    
    /// Scans all directories recursively for files with TestDoubles annotations
    private func scanForTestDoublesFiles(in directory: URL) throws -> [URL] {
        var testDoubleFiles: [URL] = []
        var seenFiles = Set<String>()
        
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .canonicalPathKey]
        
        if let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                if resourceValues.isRegularFile == true && fileURL.pathExtension == "swift" {
                    // Use canonical path to avoid duplicates from symlinks or different representations
                    let canonicalPath = resourceValues.canonicalPath ?? fileURL.path
                    
                    if seenFiles.contains(canonicalPath) {
                        continue
                    }
                    seenFiles.insert(canonicalPath)
                    
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    if content.contains("// TestDoubles:") {
                        testDoubleFiles.append(fileURL)
                    }
                }
            }
        }
        
        return testDoubleFiles
    }
}
