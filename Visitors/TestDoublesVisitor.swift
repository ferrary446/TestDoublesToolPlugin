//
//  TestDoublesVisitor.swift
//  TestDoublesToolPlugin
//
//  Created by Ilya Yushkov on 03.11.2025.
//

final class TestDoublesVisitor: SyntaxVisitor {
    private(set) var spies: [ProtocolInfo] = []
    private(set) var mocks: [ProtocolInfo] = []
    private(set) var structs: [StructInfo] = []

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check for TestDoubles annotations in leading trivia
        let leadingTrivia = node.leadingTrivia
        let triviaString = leadingTrivia.description
        
        if triviaString.contains("// TestDoubles:spy") {
            let protocolInfo = extractProtocolInfo(from: node)
            spies.append(protocolInfo)
        } else if triviaString.contains("// TestDoubles:mock") {
            let protocolInfo = extractProtocolInfo(from: node)
            mocks.append(protocolInfo)
        }
        
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check for TestDoubles:struct annotation
        let leadingTrivia = node.leadingTrivia
        let triviaString = leadingTrivia.description
        
        if triviaString.contains("// TestDoubles:struct") {
            let structInfo = extractStructInfo(from: node)
            structs.append(structInfo)
        }
        
        return .visitChildren
    }

    private func extractProtocolInfo(from node: ProtocolDeclSyntax) -> ProtocolInfo {
        let name = node.name.text
        var methods: [MethodInfo] = []
        
        for member in node.memberBlock.members {
            if let function = member.decl.as(FunctionDeclSyntax.self) {
                let methodInfo = extractMethodInfo(from: function)
                methods.append(methodInfo)
            }
        }
        
        return ProtocolInfo(name: name, methods: methods)
    }

    private func extractMethodInfo(from node: FunctionDeclSyntax) -> MethodInfo {
        let name = node.name.text
        let isAsync = node.signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrows = node.signature.effectSpecifiers?.throwsClause != nil
        
        var parameters: [ParameterInfo] = []
        if let parameterList = node.signature.parameterClause.parameters.as(FunctionParameterListSyntax.self) {
            for parameter in parameterList {
                let paramName = parameter.firstName.text
                let paramType = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
                parameters.append(ParameterInfo(name: paramName, type: paramType))
            }
        }
        
        let returnType = node.signature.returnClause?.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return MethodInfo(
            name: name,
            parameters: parameters,
            returnType: returnType,
            isAsync: isAsync,
            isThrows: isThrows
        )
    }

    private func extractStructInfo(from node: StructDeclSyntax) -> StructInfo {
        let name = node.name.text
        var properties: [PropertyInfo] = []
        
        for member in node.memberBlock.members {
            if let variable = member.decl.as(VariableDeclSyntax.self) {
                for binding in variable.bindings {
                    if let identifier = binding.pattern.as(IdentifierPatternSyntax.self) {
                        let propName = identifier.identifier.text
                        let propType = binding.typeAnnotation?.type.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
                        properties.append(PropertyInfo(name: propName, type: propType))
                    }
                }
            }
        }
        
        return StructInfo(name: name, properties: properties)
    }
}
