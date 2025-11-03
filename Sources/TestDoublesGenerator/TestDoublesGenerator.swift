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

        guard arguments.count >= 2 else {
            print("Usage: TestDoublesGenerator <input-file> [options]")
            exit(1)
        }

        let inputFilePath = arguments[1]
        
        // Check if -o flag is provided (backward compatibility)
        var outputDirectory: String
        if arguments.count >= 4 && arguments[2] == "-o" {
            outputDirectory = arguments[3]
        } else {
            outputDirectory = generateOutputDirectory(from: inputFilePath)
        }

        let generator = CodeGenerator(
            inputFilePath: inputFilePath,
            outputDirectory: outputDirectory
        )

        try await generator.generate()
    }
    
    private static func generateOutputDirectory(from inputPath: String) -> String {
        let inputURL = URL(fileURLWithPath: inputPath)
        let pathComponents = inputURL.pathComponents
        
        print("Input path: \(inputPath)")
        print("Path components: \(pathComponents)")
        
        // Strategy 1: Look for existing test directory structure
        if pathComponents.contains(where: { $0.hasSuffix("Tests") }) {
            // Already in a test project, use the same directory
            let endIndex = max(0, pathComponents.count - 1)
            let testDirectoryPath = Array(pathComponents[0..<endIndex]).joined(separator: "/")
            print("Found existing test directory: \(testDirectoryPath)")
            return testDirectoryPath
        }
        
        // Strategy 2: Find the main project directory and create corresponding test directory
        let projectIndex = findProjectDirectoryIndex(in: pathComponents)
        
        if let projectIndex = projectIndex {
            let projectName = pathComponents[projectIndex]
            let testProjectName = projectName + "Tests"
            
            print("Project name: \(projectName)")
            print("Test project name: \(testProjectName)")
            
            // Build the test directory path
            var testPathComponents: [String] = []
            
            // Add components up to (but not including) the project directory
            if projectIndex > 0 {
                testPathComponents.append(contentsOf: pathComponents[0..<projectIndex])
            }
            
            // Add the test project name
            testPathComponents.append(testProjectName)
            
            // Add the remaining path structure (everything after the project name, excluding the file)
            let remainingStartIndex = projectIndex + 1
            let remainingEndIndex = max(remainingStartIndex, pathComponents.count - 1)
            
            if remainingStartIndex < remainingEndIndex {
                testPathComponents.append(contentsOf: pathComponents[remainingStartIndex..<remainingEndIndex])
            }
            
            let testDirectoryPath = testPathComponents.joined(separator: "/")
            
            print("Generated test directory: \(testDirectoryPath)")
            
            // Create the directory if it doesn't exist
            let testDirectoryURL = URL(fileURLWithPath: testDirectoryPath)
            try? FileManager.default.createDirectory(at: testDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            
            return testDirectoryPath
        } else {
            // Strategy 3: Fallback - use parent directory
            print("Warning: Could not identify project structure, using parent directory as fallback")
            return inputURL.deletingLastPathComponent().path
        }
    }
    
    private static func findProjectDirectoryIndex(in pathComponents: [String]) -> Int? {
        // Look for common project indicators in reverse order (from the file backwards)
        for i in (0..<pathComponents.count).reversed() {
            let component = pathComponents[i]
            
            // Skip if it's already a test directory
            if component.hasSuffix("Tests") {
                continue
            }
            
            // Check if this looks like a main project directory
            if isLikelyProjectDirectory(component, at: i, in: pathComponents) {
                return i
            }
        }
        
        return nil
    }
    
    private static func isLikelyProjectDirectory(_ component: String, at index: Int, in pathComponents: [String]) -> Bool {
        // Skip system directories
        let systemDirectories = ["usr", "bin", "lib", "opt", "var", "tmp", "Applications", "Library", "System"]
        if systemDirectories.contains(component) {
            return false
        }
        
        // Skip common non-project directories
        let commonDirectories = ["Sources", "src", "Source", "Classes", "Models", "Views", "Controllers", 
                               "Scenes", "Domain", "Entities", "Presentation", "Infrastructure", 
                               "Core", "Common", "Shared", "Utils", "Utilities", "Extensions",
                               "Resources", "Assets", "Storyboards", "XIBs"]
        if commonDirectories.contains(component) {
            return false
        }
        
        // If we're looking at a directory that has source-like subdirectories, it's likely a project
        if index + 1 < pathComponents.count {
            let nextComponent = pathComponents[index + 1]
            if commonDirectories.contains(nextComponent) || nextComponent.hasSuffix(".swift") {
                return true
            }
        }
        
        // Look for Xcode project indicators
        if component.hasSuffix(".xcodeproj") || component.hasSuffix(".xcworkspace") {
            return false // These are files, not the project directory
        }
        
        // If this directory is at a reasonable depth and doesn't match common patterns, 
        // it might be a project directory
        let homeIndex = pathComponents.firstIndex(of: "Users")
        if let homeIndex = homeIndex, index > homeIndex + 2 {
            // We're past the user directory, this could be a project
            return true
        }
        
        return false
    }
}
