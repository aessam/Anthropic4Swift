import Foundation

public struct Tool: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: InputSchema
    
    public struct InputSchema: Codable, Sendable {
        public let type: String
        public let properties: [String: Property]?
        public let required: [String]?
        
        public struct Property: Codable, Sendable {
            public let type: String
            public let description: String?
            public let `enum`: [String]?
            public let items: Items?
            
            public struct Items: Codable, Sendable {
                public let type: String
                
                public init(type: String) {
                    self.type = type
                }
            }
            
            public init(
                type: String,
                description: String? = nil,
                enum: [String]? = nil,
                items: Items? = nil
            ) {
                self.type = type
                self.description = description
                self.`enum` = `enum`
                self.items = items
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case type
            case properties
            case required
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
    
    public init(name: String, description: String, inputSchema: InputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

extension Tool {
    public static func function(
        name: String,
        description: String,
        parameters: [String: Tool.InputSchema.Property] = [:],
        required: [String] = []
    ) -> Tool {
        Tool(
            name: name,
            description: description,
            inputSchema: InputSchema(
                type: "object",
                properties: parameters.isEmpty ? nil : parameters,
                required: required.isEmpty ? nil : required
            )
        )
    }
}