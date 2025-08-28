import Foundation

public protocol ToolExecutor: Sendable {
    func execute(_ toolUse: ContentBlock.ToolUseBlock) async throws -> String
}

public struct DefaultToolExecutor: ToolExecutor {
    private let tools: [String: @Sendable ([String: Any]) async throws -> String]
    
    public init() {
        self.tools = [:]
    }
    
    public init(tools: [String: @Sendable ([String: Any]) async throws -> String]) {
        self.tools = tools
    }
    
    public func execute(_ toolUse: ContentBlock.ToolUseBlock) async throws -> String {
        guard let tool = tools[toolUse.name] else {
            return "Error: Tool '\(toolUse.name)' not found"
        }
        
        let input = toolUse.input.mapValues { $0.value }
        
        do {
            return try await tool(input)
        } catch {
            return "Error executing tool '\(toolUse.name)': \(error.localizedDescription)"
        }
    }
}

public struct FunctionToolExecutor: ToolExecutor {
    private let functions: [String: any ToolFunction]
    
    public init(functions: [any ToolFunction] = []) {
        self.functions = Dictionary(uniqueKeysWithValues: functions.map { ($0.name, $0) })
    }
    
    public func execute(_ toolUse: ContentBlock.ToolUseBlock) async throws -> String {
        guard let function = functions[toolUse.name] else {
            return "Error: Function '\(toolUse.name)' not found"
        }
        
        let input = toolUse.input.mapValues { $0.value }
        return try await function.execute(with: input)
    }
}

public protocol ToolFunction: Sendable {
    var name: String { get }
    var description: String { get }
    var tool: Tool { get }
    
    func execute(with parameters: [String: Any]) async throws -> String
}

public struct SimpleToolFunction: ToolFunction {
    public let name: String
    public let description: String
    public let tool: Tool
    private let handler: @Sendable ([String: Any]) async throws -> String
    
    public init(
        name: String,
        description: String,
        parameters: [String: Tool.InputSchema.Property] = [:],
        required: [String] = [],
        handler: @escaping @Sendable ([String: Any]) async throws -> String
    ) {
        self.name = name
        self.description = description
        self.tool = Tool.function(
            name: name,
            description: description,
            parameters: parameters,
            required: required
        )
        self.handler = handler
    }
    
    public func execute(with parameters: [String: Any]) async throws -> String {
        return try await handler(parameters)
    }
}