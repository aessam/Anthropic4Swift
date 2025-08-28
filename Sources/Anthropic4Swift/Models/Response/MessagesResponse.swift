import Foundation

public struct MessagesResponse: Codable, Sendable {
    public let id: String
    public let type: String
    public let role: String
    public let content: [ContentBlock]
    public let model: String
    public let stopReason: StopReason?
    public let stopSequence: String?
    public let usage: Usage
    
    public enum StopReason: String, Codable, Sendable {
        case endTurn = "end_turn"
        case maxTokens = "max_tokens"
        case stopSequence = "stop_sequence"
        case toolUse = "tool_use"
    }
    
    public struct Usage: Codable, Sendable {
        public let inputTokens: Int
        public let outputTokens: Int
        public let cacheCreationInputTokens: Int?
        public let cacheReadInputTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
        }
        
        public var totalTokens: Int {
            inputTokens + outputTokens
        }
        
        public var estimatedCost: Double {
            let inputCost = Double(inputTokens) * 0.003 / 1000
            let outputCost = Double(outputTokens) * 0.015 / 1000
            return inputCost + outputCost
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
    
    public var textContent: String? {
        content.compactMap { block in
            if case .text(let text) = block {
                return text
            }
            return nil
        }.joined(separator: " ")
    }
    
    public var toolUses: [(id: String, name: String, input: [String: Any])] {
        content.compactMap { block in
            if case .toolUse(let toolUse) = block {
                let input = toolUse.input.mapValues { $0.value }
                return (toolUse.id, toolUse.name, input)
            }
            return nil
        }
    }
    
    public func extractToolUses() -> [ContentBlock.ToolUseBlock] {
        content.compactMap { block in
            if case .toolUse(let toolUse) = block {
                return toolUse
            }
            return nil
        }
    }
}