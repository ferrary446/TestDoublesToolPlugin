//
//  TestDoublesVisitor.swift
//  TestDoublesToolPlugin
//
//  Created by Ilya Yushkov on 03.11.2025.
//

import Foundation
import SwiftSyntax

final class TestDoublesVisitor: SyntaxVisitor {
    private(set) var spies: [ProtocolInformation] = []
    private(set) var mocks: [ProtocolInformation] = []
    private(set) var structs: [StructInformation] = []

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check for TestDoubles annotations in leading trivia
        let leadingTrivia = node.leadingTrivia
        let triviaString = leadingTrivia.description

        if triviaString.contains("// TestDoubles:spy") {
            let protocolInfo = extractProtocolInformation(from: node)
            spies.append(protocolInfo)
        } else if triviaString.contains("// TestDoubles:mock") {
            let protocolInfo = extractProtocolInformation(from: node)
            mocks.append(protocolInfo)
        }

        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check for TestDoubles:struct annotation
        let leadingTrivia = node.leadingTrivia
        let triviaString = leadingTrivia.description

        if triviaString.contains("// TestDoubles:struct") {
            let structInfo = extractStructInformation(from: node)
            structs.append(structInfo)
        }

        return .visitChildren
    }
}

// MARK: - ExtractProtocolInformation
private extension TestDoublesVisitor {
    func extractProtocolInformation(from node: ProtocolDeclSyntax) -> ProtocolInformation {
        let name = node.name.text
        var methods: [MethodInformation] = []
        
        for member in node.memberBlock.members {
            if let function = member.decl.as(FunctionDeclSyntax.self) {
                let methodInfo = extractMethodInformation(from: function)
                methods.append(methodInfo)
            }
        }
        
        return ProtocolInformation(name: name, methods: methods)
    }
}

// MARK: - ExtractMethodInformation
private extension TestDoublesVisitor {
    func extractMethodInformation(from node: FunctionDeclSyntax) -> MethodInformation {
        var parameters: [ParameterInformation] = []

        let name = node.name.text
        let isAsync = node.signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrows = node.signature.effectSpecifiers?.throwsClause != nil

        if let parameterList = node.signature.parameterClause.parameters.as(FunctionParameterListSyntax.self) {
            for parameter in parameterList {
                let paramName = parameter.firstName.text
                let paramType = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
                parameters.append(ParameterInformation(name: paramName, type: paramType))
            }
        }

        let returnType = node.signature.returnClause?.type.description.trimmingCharacters(in: .whitespacesAndNewlines)

        return MethodInformation(
            name: name,
            parameters: parameters,
            returnType: returnType,
            isAsync: isAsync,
            isThrows: isThrows
        )
    }
}

// MARK: - ExtractStructInformation
private extension TestDoublesVisitor {
    private func extractStructInformation(from node: StructDeclSyntax) -> StructInformation {
        var properties: [PropertyInformation] = []
        let name = node.name.text

        for member in node.memberBlock.members {
            if let variable = member.decl.as(VariableDeclSyntax.self) {
                for binding in variable.bindings {
                    if let identifier = binding.pattern.as(IdentifierPatternSyntax.self) {
                        let propName = identifier.identifier.text
                        let propType = binding.typeAnnotation?.type.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
                        properties.append(PropertyInformation(name: propName, type: propType))
                    }
                }
            }
        }

        return StructInformation(name: name, properties: properties)
    }
}
