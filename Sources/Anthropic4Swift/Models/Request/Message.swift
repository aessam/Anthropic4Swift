import Foundation

public struct Message: Codable, Sendable {
    public let role: Role
    public let content: Content
    
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
    }
    
    public enum Content: Codable, Sendable {
        case text(String)
        case blocks([ContentBlock])
        
        public func encode(to encoder: Encoder) throws {
            switch self {
            case .text(let text):
                var container = encoder.singleValueContainer()
                try container.encode(text)
            case .blocks(let blocks):
                var container = encoder.singleValueContainer()
                try container.encode(blocks)
            }
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else if let blocks = try? container.decode([ContentBlock].self) {
                self = .blocks(blocks)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Content must be either a string or array of content blocks"
                )
            }
        }
    }
    
    public init(role: Role, content: Content) {
        self.role = role
        self.content = content
    }
    
    public init(role: Role, text: String) {
        self.role = role
        self.content = .text(text)
    }
    
    public init(role: Role, blocks: [ContentBlock]) {
        self.role = role
        self.content = .blocks(blocks)
    }
}

extension Message {
    public static func user(_ text: String) -> Message {
        Message(role: .user, text: text)
    }
    
    public static func user(_ blocks: [ContentBlock]) -> Message {
        Message(role: .user, blocks: blocks)
    }
    
    public static func assistant(_ text: String) -> Message {
        Message(role: .assistant, text: text)
    }
    
    public static func assistant(_ blocks: [ContentBlock]) -> Message {
        Message(role: .assistant, blocks: blocks)
    }
    
    public var textContent: String? {
        switch content {
        case .text(let text):
            return text
        case .blocks(let blocks):
            return blocks.compactMap { block in
                if case .text(let text) = block {
                    return text
                }
                return nil
            }.joined(separator: " ")
        }
    }
}