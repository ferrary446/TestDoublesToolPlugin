//
//  CodeGenerator.swift
//  TestDoublesToolPlugin
//
//  Created by Ilya Yushkov on 03.11.2025.
//

import Foundation
import SwiftParser

struct CodeGenerator {
    let inputFilePath: String
    let outputDirectory: String
    
    func generate() async throws {
        let inputURL = URL(fileURLWithPath: inputFilePath)
        let sourceCode = try String(contentsOf: inputURL)
        
        // Extract project name from the file path
        let projectName = extractProjectName(from: inputFilePath)
        
        let tree = Parser.parse(source: sourceCode)
        let visitor = TestDoublesVisitor(viewMode: .all)
        visitor.walk(tree)
        
        // Generate spy files
        for spy in visitor.spies {
            let spyCode = generateSpy(spy, projectName: projectName)
            let outputPath = outputDirectory + "/" + spy.name + "Spy.swift"
            try spyCode.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
        }
        
        // Generate mock files
        for mock in visitor.mocks {
            let mockCode = generateMock(mock, projectName: projectName)
            let outputPath = outputDirectory + "/" + mock.name + "Mock.swift"
            try mockCode.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
        }
        
        // Generate struct extensions
        for structInfo in visitor.structs {
            let extensionCode = generateStructExtension(structInfo, projectName: projectName)
            let outputPath = outputDirectory + "/" + structInfo.name + "+Mock.swift"
            try extensionCode.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - GenerateSpy
private extension CodeGenerator {
    func generateSpy(_ protocolInfo: ProtocolInformation, projectName: String) -> String {
        let className = "\(protocolInfo.name)Spy"
        
        var code = """
import Foundation
@testable import \(projectName)

final class \(className): \(protocolInfo.name) {

"""
        
        // Generate Call structs for each method
        for method in protocolInfo.methods {
            if !method.parameters.isEmpty {
                code += "    struct \(method.name.capitalized)Call {\n"
                for param in method.parameters {
                    let cleanType = cleanParameterType(param.type)
                    code += "        let \(param.name): \(cleanType)\n"
                }
                code += "    }\n\n"
            }
        }
        
        // Generate call tracking properties
        for method in protocolInfo.methods {
            if method.parameters.isEmpty {
                code += "    private(set) var \(method.name)CallCount = 0\n"
            } else {
                code += "    private(set) var \(method.name)Calls = [\(method.name.capitalized)Call]()\n"
            }
        }
        
        // Generate error properties for throwing methods
        for method in protocolInfo.methods where method.isThrows {
            code += "    private let \(method.name)ErrorToThrow: (() -> Error)?\n"
        }
        
        // Generate return value properties for methods with return types
        for method in protocolInfo.methods {
            if let returnType = method.returnType, !returnType.isEmpty && returnType != "Void" {
                code += "    private let \(method.name)ReturnValue: \(returnType)\n"
            }
        }
        
        code += "\n"
        
        // Generate initializer
        code += "    init("
        
        var initParams: [String] = []
        
        // Add return value parameters first
        let methodsWithReturnValues = protocolInfo.methods.filter { method in
            if let returnType = method.returnType, !returnType.isEmpty && returnType != "Void" {
                return true
            }
            return false
        }
        
        for method in methodsWithReturnValues {
            if let returnType = method.returnType {
                initParams.append("\(method.name)ReturnValue: \(returnType)")
            }
        }
        
        // Add error parameters after return values
        let throwingMethods = protocolInfo.methods.filter { $0.isThrows }
        for method in throwingMethods {
            initParams.append("\(method.name)ErrorToThrow: (() -> Error)? = nil")
        }
        
        code += initParams.joined(separator: ", ")
        code += ") {\n"
        
        // Initialize return values
        for method in methodsWithReturnValues {
            code += "        self.\(method.name)ReturnValue = \(method.name)ReturnValue\n"
        }
        
        // Initialize error handlers
        for method in throwingMethods {
            code += "        self.\(method.name)ErrorToThrow = \(method.name)ErrorToThrow\n"
        }
        code += "    }\n\n"
        
        // Generate method implementations
        for method in protocolInfo.methods {
            code += "    func \(method.name)("
            
            let paramStrings = method.parameters.map { "\($0.name): \($0.type)" }
            code += paramStrings.joined(separator: ", ")
            code += ")"
            
            if method.isAsync {
                code += " async"
            }
            
            if method.isThrows {
                code += " throws"
            }
            
            if let returnType = method.returnType, !returnType.isEmpty && returnType != "Void" {
                code += " -> \(returnType)"
            }
            
            code += " {\n"
            
            // Track the call
            if method.parameters.isEmpty {
                code += "        \(method.name)CallCount += 1\n"
            } else {
                code += "        \(method.name)Calls.append(\(method.name.capitalized)Call("
                let callParams = method.parameters.map { "\($0.name): \($0.name)" }
                code += callParams.joined(separator: ", ")
                code += "))\n"
            }
            
            // Throw error if needed
            if method.isThrows {
                code += "\n        if let \(method.name)ErrorToThrow {\n"
                code += "            throw \(method.name)ErrorToThrow()\n"
                code += "        }\n"
            }
            
            // Return value if needed
            if let returnType = method.returnType, !returnType.isEmpty && returnType != "Void" {
                code += "\n        return \(method.name)ReturnValue\n"
            }
            
            code += "    }\n\n"
        }
        
        code += "}\n"
        return code
    }
}

// MARK: - GenerateMock
private extension CodeGenerator {
    func generateMock(_ protocolInfo: ProtocolInformation, projectName: String) -> String {
        // Similar to spy but with different behavior - placeholder for now
        return generateSpy(protocolInfo, projectName: projectName).replacingOccurrences(of: "Spy", with: "Mock")
    }
}

// MARK: - GenerateStruct
private extension CodeGenerator {
    func generateStructExtension(_ structInfo: StructInformation, projectName: String) -> String {
        var code = """
import Foundation
@testable import \(projectName)

extension \(structInfo.name) {
    static func makeMock(

"""
        
        let paramStrings = structInfo.properties.map { property in
            let defaultValue = generateDefaultValue(for: property.type)
            return "        \(property.name): \(property.type) = \(defaultValue)"
        }
        
        code += paramStrings.joined(separator: ",\n")
        code += "\n    ) -> Self {\n"
        code += "        \(structInfo.name)(\n"
        
        let initParams = structInfo.properties.map { "            \($0.name): \($0.name)" }
        code += initParams.joined(separator: ",\n")
        code += "\n        )\n"
        code += "    }\n"
        code += "}\n"
        
        return code
    }
}

// MARK: - Helper Functions
private extension CodeGenerator {
    /// Extracts the project name from the file path
    /// Example: "/Users/user/Desktop/PeakTrack/PeakTrack/File.swift" -> "PeakTrack"
    func extractProjectName(from filePath: String) -> String {
        let url = URL(fileURLWithPath: filePath)
        let pathComponents = url.pathComponents
        
        // Look for the main project directory by finding repeated directory names
        // or look for .xcodeproj patterns in parent directories
        for (index, component) in pathComponents.enumerated() {
            // Skip common non-project directories
            if component == "/" || component == "Users" || component.hasPrefix(".") {
                continue
            }
            
            // Look for next component that matches (common pattern: /ProjectName/ProjectName/)
            if index + 1 < pathComponents.count && pathComponents[index + 1] == component {
                return component
            }
            
            // If we find a component that looks like a project name (capitalized, not common directory)
            if component.first?.isUppercase == true && 
               !["Desktop", "Documents", "Downloads", "Library"].contains(component) {
                return component
            }
        }
        
        // Fallback: use the directory name that contains the source file
        return url.deletingLastPathComponent().lastPathComponent
    }
    
    /// Cleans parameter types for use in property declarations
    /// Removes @escaping and other function-only attributes that are invalid in struct properties
    /// 
    /// Example: "@escaping (_ id: UUID) -> Void" becomes "(_ id: UUID) -> Void"
    func cleanParameterType(_ type: String) -> String {
        return type
            .replacingOccurrences(of: "@escaping ", with: "")
            .replacingOccurrences(of: "@escaping", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - GenerateDefaultValue
private extension CodeGenerator {
    func generateDefaultValue(for type: String) -> String {
        switch type {
        case "String":
            return "\"name\""
        case "Int":
            return "0"
        case "Double", "Float":
            return "0.0"
        case "Bool":
            return "false"
        case "UUID":
            return "UUID()"
        case let arrayType where arrayType.hasPrefix("[") && arrayType.hasSuffix("]"):
            return "[]"
        case let optionalType where optionalType.hasSuffix("?"):
            return "nil"
        default:
            // Try to extract the type name for custom types
            let cleanType = type.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanType.contains("<") {
                // Generic type, return default based on container
                if cleanType.hasPrefix("Array") || cleanType.hasPrefix("[") {
                    return "[]"
                } else if cleanType.hasPrefix("Set") {
                    return "Set()"
                } else if cleanType.hasPrefix("Dictionary") {
                    return "[:]"
                }
            }
            
            // For custom types, use a generic string
            let typeName = cleanType.components(separatedBy: "<").first ?? cleanType
            return "\"\(typeName.lowercased())\""
        }
    }
}
