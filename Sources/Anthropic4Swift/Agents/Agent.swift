import Foundation

public actor Agent {
    public let systemPrompt: String?
    public let tools: [Tool]
    public let model: String
    public let maxTokens: Int
    public let temperature: Double?
    
    private let client: AnthropicClient
    private let conversation: Conversation
    private let toolExecutor: ToolExecutor?
    
    public init(
        apiKey: String,
        systemPrompt: String? = nil,
        tools: [Tool] = [],
        toolExecutor: ToolExecutor? = nil,
        model: String = MessagesRequest.defaultModel,
        maxTokens: Int = 4096,
        temperature: Double? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.toolExecutor = toolExecutor
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.client = AnthropicClient(apiKey: apiKey)
        self.conversation = Conversation()
    }
    
    public init(
        client: AnthropicClient,
        systemPrompt: String? = nil,
        tools: [Tool] = [],
        toolExecutor: ToolExecutor? = nil,
        model: String = MessagesRequest.defaultModel,
        maxTokens: Int = 4096,
        temperature: Double? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.toolExecutor = toolExecutor
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.client = client
        self.conversation = Conversation()
    }
    
    public func send(_ message: String) async throws -> String {
        conversation.addUserMessage(text: message)
        return try await processUntilComplete()
    }
    
    public func send(_ blocks: [ContentBlock]) async throws -> String {
        conversation.addUserMessage(blocks: blocks)
        return try await processUntilComplete()
    }
    
    private func processUntilComplete() async throws -> String {
        var maxIterations = 10
        
        while maxIterations > 0 {
            let request = conversation.buildRequest(
                model: model,
                maxTokens: maxTokens,
                system: systemPrompt,
                tools: tools.isEmpty ? nil : tools,
                temperature: temperature
            )
            
            let response = try await client.send(request)
            conversation.addAssistantResponse(response)
            
            let toolUses = response.extractToolUses()
            
            if toolUses.isEmpty {
                return response.textContent ?? ""
            }
            
            guard let toolExecutor = toolExecutor else {
                let toolNames = toolUses.map { $0.name }.joined(separator: ", ")
                return "Error: No tool executor available to handle tools: \(toolNames)"
            }
            
            for toolUse in toolUses {
                do {
                    let result = try await toolExecutor.execute(toolUse)
                    conversation.addToolResult(id: toolUse.id, result: result)
                } catch {
                    conversation.addToolResult(
                        id: toolUse.id,
                        result: "Error: \(error.localizedDescription)"
                    )
                }
            }
            
            maxIterations -= 1
        }
        
        throw AnthropicError.apiError(
            429,
            "Maximum tool execution iterations reached. Possible infinite loop."
        )
    }
    
    public func clearConversation() {
        conversation.clear()
    }
    
    public var messages: [Message] {
        conversation.messages
    }
    
    public var messageCount: Int {
        conversation.messageCount
    }
    
    public func getLastToolUses() -> [ContentBlock.ToolUseBlock] {
        conversation.getLastToolUses()
    }
}

extension Agent {
    public static func simple(
        apiKey: String,
        systemPrompt: String? = nil,
        model: String = MessagesRequest.defaultModel
    ) -> Agent {
        Agent(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            model: model
        )
    }
    
    public static func withTools(
        apiKey: String,
        systemPrompt: String? = nil,
        functions: [any ToolFunction],
        model: String = MessagesRequest.defaultModel
    ) -> Agent {
        let tools = functions.map { $0.tool }
        let executor = FunctionToolExecutor(functions: functions)
        
        return Agent(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            tools: tools,
            toolExecutor: executor,
            model: model
        )
    }
}