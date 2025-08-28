import Foundation

public enum ContentBlock: Codable, Sendable {
    case text(String)
    case image(ImageBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)
    
    public struct ImageBlock: Codable, Sendable {
        public let type: String = "image"
        public let source: ImageSource
        
        public struct ImageSource: Codable, Sendable {
            public let type: String = "base64"
            public let mediaType: String
            public let data: String
            
            enum CodingKeys: String, CodingKey {
                case type
                case mediaType = "media_type"
                case data
            }
        }
    }
    
    public struct ToolUseBlock: Codable, Sendable {
        public let type: String = "tool_use"
        public let id: String
        public let name: String
        public let input: [String: AnyCodable]
    }
    
    public struct ToolResultBlock: Codable, Sendable {
        public let type: String = "tool_result"
        public let toolUseId: String
        public let content: String
        
        enum CodingKeys: String, CodingKey {
            case type
            case toolUseId = "tool_use_id"
            case content
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            let textContainer = try decoder.container(keyedBy: TextKeys.self)
            let text = try textContainer.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            let image = try ImageBlock(from: decoder)
            self = .image(image)
        case "tool_use":
            let toolUse = try ToolUseBlock(from: decoder)
            self = .toolUse(toolUse)
        case "tool_result":
            let toolResult = try ToolResultBlock(from: decoder)
            self = .toolResult(toolResult)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content block type: \(type)"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let text):
            var container = encoder.container(keyedBy: TextKeys.self)
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let image):
            try image.encode(to: encoder)
        case .toolUse(let toolUse):
            try toolUse.encode(to: encoder)
        case .toolResult(let toolResult):
            try toolResult.encode(to: encoder)
        }
    }
    
    enum TextKeys: String, CodingKey {
        case type
        case text
    }
}

public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}