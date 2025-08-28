import Foundation

public struct MessagesRequest: Codable, Sendable {
    public let model: String
    public let messages: [Message]
    public let maxTokens: Int
    public let system: SystemPrompt?
    public let tools: [Tool]?
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let stream: Bool?
    public let stopSequences: [String]?
    public let metadata: Metadata?
    
    public enum SystemPrompt: Codable, Sendable {
        case text(String)
        case blocks([SystemBlock])
        
        public struct SystemBlock: Codable, Sendable {
            public let type: String = "text"
            public let text: String
        }
        
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
            } else if let blocks = try? container.decode([SystemBlock].self) {
                self = .blocks(blocks)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "System must be either a string or array of system blocks"
                )
            }
        }
        
        public func toText() -> String {
            switch self {
            case .text(let text):
                return text
            case .blocks(let blocks):
                return blocks.map { $0.text }.joined(separator: " ")
            }
        }
    }
    
    public struct Metadata: Codable, Sendable {
        public let userId: String?
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
        }
        
        public init(userId: String? = nil) {
            self.userId = userId
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case system
        case tools
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case stream
        case stopSequences = "stop_sequences"
        case metadata
    }
    
    public init(
        model: String,
        messages: [Message],
        maxTokens: Int = 4096,
        system: String? = nil,
        tools: [Tool]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stream: Bool? = nil,
        stopSequences: [String]? = nil,
        metadata: Metadata? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.system = system.map { .text($0) }
        self.tools = tools
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stream = stream
        self.stopSequences = stopSequences
        self.metadata = metadata
    }
}

extension MessagesRequest {
    public static let defaultModel = "claude-3-5-sonnet-20241022"
    
    public static func simple(
        prompt: String,
        model: String = defaultModel,
        maxTokens: Int = 4096
    ) -> MessagesRequest {
        MessagesRequest(
            model: model,
            messages: [.user(prompt)],
            maxTokens: maxTokens
        )
    }
}