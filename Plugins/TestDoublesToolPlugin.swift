//
//  TestDoublesToolPlugin.swift
//  TestDoublesToolPlugin
//
//  Created by Ilya Yushkov on 03.11.2025.
//

import Foundation
import PackagePlugin

@main
struct TestDoublesToolPlugin: CommandPlugin {
    /// Entry point for command execution in Swift packages.
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        // Find the code generator tool to run.
        let generatorTool = try context.tool(named: "TestDoublesGenerator")
        
        // Parse arguments to determine target or use all targets
        let targetNames = Set(arguments)
        let targetsToProcess = targetNames.isEmpty ? context.package.targets : context.package.targets.filter { targetNames.contains($0.name) }
        
        for target in targetsToProcess {
            // This plugin only runs for package targets that can have source files.
            guard let sourceFiles = target.sourceModule?.sourceFiles else { continue }
            
            print("Processing target: \(target.name)")
            
            // Only process Swift files that contain TestDoubles annotations
            let swiftFiles = sourceFiles.filter { $0.url.pathExtension == "swift" }
            
            for sourceFile in swiftFiles {
                try await processFile(sourceFile.url, with: generatorTool.url, in: context.pluginWorkDirectoryURL)
            }
        }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension TestDoublesToolPlugin: XcodeCommandPlugin {
    // Entry point for command execution in Xcode projects.
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        // Find the code generator tool to run.
        let generatorTool = try context.tool(named: "TestDoublesGenerator")
        
        // Parse arguments to determine targets or use all targets
        let targetNames = Set(arguments)
        let targetsToProcess = targetNames.isEmpty ? context.xcodeProject.targets : context.xcodeProject.targets.filter { targetNames.contains($0.displayName) }
        
        for target in targetsToProcess {
            print("Processing Xcode target: \(target.displayName)")
            
            // Only process Swift files that contain TestDoubles annotations
            let swiftFiles = target.inputFiles.filter { $0.url.pathExtension == "swift" }
            
            for inputFile in swiftFiles {
                try processFileSync(inputFile.url, with: generatorTool.url, in: context.pluginWorkDirectoryURL)
            }
        }
    }
}

#endif

extension TestDoublesToolPlugin {
    /// Process a file asynchronously, executing the generator tool if needed.
    func processFile(
        _ inputPath: URL,
        with generatorToolPath: URL,
        in workingDirectory: URL
    ) async throws {
        guard inputPath.pathExtension == "swift" else { return }

        let content = try String(contentsOf: inputPath, encoding: .utf8)
        guard content.contains("// TestDoubles:") else { 
            print("Skipping \(inputPath.lastPathComponent) - no TestDoubles annotations found")
            return 
        }

        let outDir = workingDirectory.appendingPathComponent("DerivedSources", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let outputs = inferOutputs(from: content, outputDir: outDir)
        guard !outputs.isEmpty else { 
            print("Skipping \(inputPath.lastPathComponent) - no valid output files detected")
            return 
        }

        print("Generating test doubles from \(inputPath.lastPathComponent)")
        
        // Execute the generator tool
        let process = Process()
        process.executableURL = generatorToolPath
        process.arguments = [inputPath.path, "-o", outDir.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            print("✅ Generated files: \(outputs.map { $0.lastPathComponent }.joined(separator: ", "))")
        } else {
            print("❌ Failed to generate test doubles for \(inputPath.lastPathComponent)")
        }
    }
    
    /// Synchronous version for Xcode plugin compatibility.
    func processFileSync(
        _ inputPath: URL,
        with generatorToolPath: URL,
        in workingDirectory: URL
    ) throws {
        guard inputPath.pathExtension == "swift" else { return }

        let content = try String(contentsOf: inputPath, encoding: .utf8)
        guard content.contains("// TestDoubles:") else { 
            print("Skipping \(inputPath.lastPathComponent) - no TestDoubles annotations found")
            return 
        }

        let outDir = workingDirectory.appendingPathComponent("DerivedSources", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let outputs = inferOutputs(from: content, outputDir: outDir)
        guard !outputs.isEmpty else { 
            print("Skipping \(inputPath.lastPathComponent) - no valid output files detected")
            return 
        }

        print("Generating test doubles from \(inputPath.lastPathComponent)")
        
        // Execute the generator tool
        let process = Process()
        process.executableURL = generatorToolPath
        process.arguments = [inputPath.path, "-o", outDir.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            print("✅ Generated files: \(outputs.map { $0.lastPathComponent }.joined(separator: ", "))")
        } else {
            print("❌ Failed to generate test doubles for \(inputPath.lastPathComponent)")
        }
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
