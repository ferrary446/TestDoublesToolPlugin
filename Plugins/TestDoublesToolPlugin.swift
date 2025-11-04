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
        print("🚀 TestDoublesToolPlugin starting in Xcode...")
        print("📁 Working directory: \(context.pluginWorkDirectoryURL)")
        print("📁 Project directory: \(context.xcodeProject.directoryURL)")
        print("🎯 Arguments: \(arguments)")
        
        // Find the code generator tool to run.
        do {
            let generatorTool = try context.tool(named: "TestDoublesGenerator")
            print("🔧 Found generator tool at: \(generatorTool.url)")
        } catch {
            print("❌ Failed to find TestDoublesGenerator tool: \(error)")
            throw error
        }
        
        let generatorTool = try context.tool(named: "TestDoublesGenerator")
        
        // Parse arguments to determine targets or use all targets
        let targetNames = Set(arguments)
        let targetsToProcess = targetNames.isEmpty ? context.xcodeProject.targets : context.xcodeProject.targets.filter { targetNames.contains($0.displayName) }
        
        print("📋 Found \(context.xcodeProject.targets.count) total targets")
        print("🎯 Processing \(targetsToProcess.count) targets: \(targetsToProcess.map { $0.displayName })")
        
        var totalFilesProcessed = 0
        
        for target in targetsToProcess {
            print("📂 Processing Xcode target: \(target.displayName) (\(target.inputFiles.count) files)")
            
            // Only process Swift files that contain TestDoubles annotations
            let swiftFiles = target.inputFiles.filter { $0.url.pathExtension == "swift" }
            print("   📝 Swift files: \(swiftFiles.count)")
            
            for inputFile in swiftFiles {
                try processFileForXcode(inputFile.url, with: generatorTool.url, projectDirectory: context.xcodeProject.directoryURL, targetName: target.displayName)
                totalFilesProcessed += 1
            }
        }
        
        print("✅ Plugin completed. Processed \(totalFilesProcessed) files total.")
    }
}

#endif

extension TestDoublesToolPlugin {
    /// Determines the appropriate test doubles output directory based on the source file structure
    private func determineTestDoublesPath(
        for sourceFile: URL,
        projectDirectory: URL,
        targetName: String
    ) -> URL {
        // Get the relative path from project directory to source file
        let relativePath = sourceFile.path.replacingOccurrences(of: projectDirectory.path + "/", with: "")
        
        // Extract the path components
        let pathComponents = relativePath.split(separator: "/").map(String.init)
        
        // Find the main target name in the path (usually the first component after project root)
        guard let mainTargetIndex = pathComponents.firstIndex(where: { component in
            // Look for common main target patterns
            return !component.hasSuffix("Tests") && 
                   !component.hasSuffix("UITests") && 
                   component != "TestDoubles" &&
                   component.first?.isUppercase == true
        }) else {
            // Fallback: create TestDoubles in project root with mirrored structure
            let remainingPath = pathComponents.dropFirst().dropLast().joined(separator: "/")
            return projectDirectory
                .appendingPathComponent("\(targetName.replacingOccurrences(of: "Tests", with: ""))Tests")
                .appendingPathComponent("TestDoubles")
                .appendingPathComponent(remainingPath)
        }
        
        let mainTargetName = pathComponents[mainTargetIndex]
        let testTargetName = mainTargetName + "Tests"
        
        // Get the path after the main target directory
        let pathAfterTarget = pathComponents[(mainTargetIndex + 1)...].dropLast() // Drop the file name
        let relativeDirPath = pathAfterTarget.joined(separator: "/")
        
        // Construct the test doubles path: ProjectRoot/MainTargetTests/TestDoubles/...
        var testDoublesPath = projectDirectory
            .appendingPathComponent(testTargetName)
            .appendingPathComponent("TestDoubles")
        
        if !relativeDirPath.isEmpty {
            testDoublesPath = testDoublesPath.appendingPathComponent(relativeDirPath)
        }
        
        return testDoublesPath
    }
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

        print("🔧 Generating test doubles from \(inputPath.lastPathComponent)")
        
        // Execute the generator tool
        let process = Process()
        process.executableURL = generatorToolPath
        process.arguments = [inputPath.path, "-o", outDir.path]
        
        // Capture output for better debugging
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Read output
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                print("✅ Generated files: \(outputs.map { $0.lastPathComponent }.joined(separator: ", "))")
                if !output.isEmpty {
                    print("   Output: \(output)")
                }
            } else {
                print("❌ Failed to generate test doubles for \(inputPath.lastPathComponent)")
                print("   Exit code: \(process.terminationStatus)")
                if !output.isEmpty {
                    print("   Error output: \(output)")
                }
            }
        } catch {
            print("❌ Failed to execute generator tool: \(error)")
            throw error
        }
    }
    
    /// Process a file for Xcode projects, generating files in the project structure.
    func processFileForXcode(
        _ inputPath: URL,
        with generatorToolPath: URL,
        projectDirectory: URL,
        targetName: String
    ) throws {
        guard inputPath.pathExtension == "swift" else { return }

        let content = try String(contentsOf: inputPath, encoding: .utf8)
        guard content.contains("// TestDoubles:") else { 
            print("Skipping \(inputPath.lastPathComponent) - no TestDoubles annotations found")
            return 
        }

        // Create TestDoubles directory with mirrored structure
        let testDoublesDir = determineTestDoublesPath(
            for: inputPath,
            projectDirectory: projectDirectory,
            targetName: targetName
        )
        try FileManager.default.createDirectory(at: testDoublesDir, withIntermediateDirectories: true)

        let outputs = inferOutputs(from: content, outputDir: testDoublesDir)
        guard !outputs.isEmpty else { 
            print("Skipping \(inputPath.lastPathComponent) - no valid output files detected")
            return 
        }

        print("🔧 Generating test doubles from \(inputPath.lastPathComponent) for Xcode")
        
        // Execute the generator tool
        let process = Process()
        process.executableURL = generatorToolPath
        process.arguments = [inputPath.path, "-o", testDoublesDir.path]
        
        // Capture output for better debugging
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Read output
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                print("✅ Generated files: \(outputs.map { $0.lastPathComponent }.joined(separator: ", "))")
                print("📁 Files created at: \(testDoublesDir.path)")
                print("➡️  Add these files to your test target in Xcode")
                
                if !output.isEmpty {
                    print("   Generator output: \(output)")
                }
            } else {
                print("❌ Failed to generate test doubles for \(inputPath.lastPathComponent)")
                print("   Exit code: \(process.terminationStatus)")
                if !output.isEmpty {
                    print("   Error output: \(output)")
                }
            }
        } catch {
            print("❌ Failed to execute generator tool: \(error)")
            throw error
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
