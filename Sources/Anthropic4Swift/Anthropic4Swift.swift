import Foundation

// MARK: - Package Info

public enum Anthropic4Swift {
    public static let version = "1.0.0"
    public static let defaultModel = MessagesRequest.defaultModel
}

// MARK: - Convenience Extensions

extension Agent {
    /// Create a simple conversational agent
    public static func conversation(
        apiKey: String,
        systemPrompt: String? = nil
    ) -> Agent {
        Agent.simple(apiKey: apiKey, systemPrompt: systemPrompt)
    }
    
    /// Create an agent with custom tools
    public static func withCustomTools(
        apiKey: String,
        systemPrompt: String? = nil,
        tools: [String: @Sendable ([String: Any]) async throws -> String]
    ) -> Agent {
        let executor = DefaultToolExecutor(tools: tools)
        let toolDefinitions = tools.map { name, _ in
            Tool.function(name: name, description: "Custom tool: \(name)")
        }
        
        return Agent(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            tools: toolDefinitions,
            toolExecutor: executor
        )
    }
}

extension AnthropicClient {
    /// Quick completion with simple text
    public func ask(_ question: String) async throws -> String {
        try await complete(question)
    }
    
    /// Stream a simple question
    @available(macOS 10.15, *)
    public func askStreaming(_ question: String) -> AsyncThrowingStream<String, Error> {
        streamComplete(question)
    }
}
