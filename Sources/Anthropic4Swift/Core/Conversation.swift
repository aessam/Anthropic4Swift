import Foundation

public final class Conversation: @unchecked Sendable {
    private let lock = NSLock()
    private var _messages: [Message] = []
    
    public var messages: [Message] {
        lock.withLock { _messages }
    }
    
    public var isEmpty: Bool {
        lock.withLock { _messages.isEmpty }
    }
    
    public var messageCount: Int {
        lock.withLock { _messages.count }
    }
    
    public init() {}
    
    public func addMessage(_ message: Message) {
        lock.withLock {
            _messages.append(message)
        }
    }
    
    public func addUserMessage(text: String) {
        addMessage(.user(text))
    }
    
    public func addUserMessage(blocks: [ContentBlock]) {
        addMessage(.user(blocks))
    }
    
    public func addAssistantResponse(_ response: MessagesResponse) {
        addMessage(.assistant(response.content))
    }
    
    public func addToolResult(id: String, result: String) {
        let toolResultBlock = ContentBlock.toolResult(
            ContentBlock.ToolResultBlock(
                toolUseId: id,
                content: result
            )
        )
        addMessage(.user([toolResultBlock]))
    }
    
    public func clear() {
        lock.withLock {
            _messages.removeAll()
        }
    }
    
    public func buildRequest(
        model: String = MessagesRequest.defaultModel,
        maxTokens: Int = 4096,
        system: String? = nil,
        tools: [Tool]? = nil,
        temperature: Double? = nil
    ) -> MessagesRequest {
        let currentMessages = messages
        
        return MessagesRequest(
            model: model,
            messages: currentMessages,
            maxTokens: maxTokens,
            system: system,
            tools: tools,
            temperature: temperature
        )
    }
    
    public func pruneToTokenLimit(_ tokenLimit: Int) {
        lock.withLock {
            let estimatedTokens = _messages.reduce(0) { total, message in
                return total + estimateTokenCount(for: message)
            }
            
            if estimatedTokens > tokenLimit {
                let targetTokens = Int(Double(tokenLimit) * 0.8)
                var currentTokens = estimatedTokens
                var removeCount = 0
                
                for message in _messages {
                    if currentTokens <= targetTokens { break }
                    currentTokens -= estimateTokenCount(for: message)
                    removeCount += 1
                }
                
                if removeCount > 0 && removeCount < _messages.count {
                    _messages.removeFirst(removeCount)
                }
            }
        }
    }
    
    private func estimateTokenCount(for message: Message) -> Int {
        switch message.content {
        case .text(let text):
            return text.count / 4
        case .blocks(let blocks):
            return blocks.reduce(0) { total, block in
                switch block {
                case .text(let text):
                    return total + text.count / 4
                case .image:
                    return total + 1500
                case .toolUse, .toolResult:
                    return total + 100
                }
            }
        }
    }
    
    public var lastMessage: Message? {
        messages.last
    }
    
    public var lastUserMessage: Message? {
        messages.reversed().first { $0.role == .user }
    }
    
    public var lastAssistantMessage: Message? {
        messages.reversed().first { $0.role == .assistant }
    }
    
    public func getLastToolUses() -> [ContentBlock.ToolUseBlock] {
        guard let lastAssistant = lastAssistantMessage,
              case .blocks(let blocks) = lastAssistant.content else {
            return []
        }
        
        return blocks.compactMap { block in
            if case .toolUse(let toolUse) = block {
                return toolUse
            }
            return nil
        }
    }
}