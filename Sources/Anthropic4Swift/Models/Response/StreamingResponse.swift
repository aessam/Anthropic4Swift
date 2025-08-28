import Foundation

public enum StreamEvent: Sendable {
    case messageStart(MessageStart)
    case messageStop(MessageStop)
    case messageDelta(MessageDelta)
    case contentBlockStart(ContentBlockStart)
    case contentBlockStop(ContentBlockStop)
    case contentBlockDelta(ContentBlockDelta)
    case ping
    case error(String)
    
    public struct MessageStart: Codable, Sendable {
        public let message: PartialMessage
        
        public struct PartialMessage: Codable, Sendable {
            public let id: String
            public let type: String
            public let role: String
            public let content: [String]
            public let model: String
            public let stopReason: String?
            public let stopSequence: String?
            public let usage: MessagesResponse.Usage
            
            enum CodingKeys: String, CodingKey {
                case id, type, role, content, model
                case stopReason = "stop_reason"
                case stopSequence = "stop_sequence"
                case usage
            }
        }
    }
    
    public struct MessageStop: Codable, Sendable {
        public let usage: MessagesResponse.Usage?
        
        public init(usage: MessagesResponse.Usage?) {
            self.usage = usage
        }
    }
    
    public struct MessageDelta: Codable, Sendable {
        public let delta: Delta
        public let usage: MessagesResponse.Usage?
        
        public struct Delta: Codable, Sendable {
            public let stopReason: String?
            public let stopSequence: String?
            
            enum CodingKeys: String, CodingKey {
                case stopReason = "stop_reason"
                case stopSequence = "stop_sequence"
            }
        }
    }
    
    public struct ContentBlockStart: Codable, Sendable {
        public let index: Int
        public let contentBlock: PartialContentBlock
        
        public struct PartialContentBlock: Codable, Sendable {
            public let type: String
            public let text: String?
            public let id: String?
            public let name: String?
            public let input: [String: AnyCodable]?
        }
        
        enum CodingKeys: String, CodingKey {
            case index
            case contentBlock = "content_block"
        }
    }
    
    public struct ContentBlockStop: Codable, Sendable {
        public let index: Int
    }
    
    public struct ContentBlockDelta: Codable, Sendable {
        public let index: Int
        public let delta: Delta
        
        public struct Delta: Codable, Sendable {
            public let type: String
            public let text: String?
            public let partialJson: String?
            
            enum CodingKeys: String, CodingKey {
                case type, text
                case partialJson = "partial_json"
            }
        }
    }
}

public struct StreamingResponseParser {
    public static func parseEvent(from line: String) -> StreamEvent? {
        guard line.hasPrefix("data: ") else {
            return nil
        }
        
        let jsonString = String(line.dropFirst(6))
        
        if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
            return nil
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            return .error("Failed to parse JSON data")
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            guard let eventType = json?["type"] as? String else {
                return .error("Missing event type")
            }
            
            switch eventType {
            case "message_start":
                if let messageData = try? JSONSerialization.data(withJSONObject: json!, options: []),
                   let messageStart = try? JSONDecoder().decode(StreamEvent.MessageStart.self, from: messageData) {
                    return .messageStart(messageStart)
                }
                return .error("Failed to parse message_start")
                
            case "message_stop":
                // message_stop might come with or without usage
                if let eventData = try? JSONSerialization.data(withJSONObject: json!, options: []),
                   let messageStop = try? JSONDecoder().decode(StreamEvent.MessageStop.self, from: eventData) {
                    return .messageStop(messageStop)
                } else if let message = json?["message"] as? [String: Any],
                          let usage = message["usage"] as? [String: Any],
                          let usageData = try? JSONSerialization.data(withJSONObject: usage, options: []),
                          let usageObject = try? JSONDecoder().decode(MessagesResponse.Usage.self, from: usageData) {
                    return .messageStop(StreamEvent.MessageStop(usage: usageObject))
                } else {
                    // Return empty message_stop if no usage data
                    return .messageStop(StreamEvent.MessageStop(usage: nil))
                }
                
            case "message_delta":
                if let eventData = try? JSONSerialization.data(withJSONObject: json!, options: []),
                   let messageDelta = try? JSONDecoder().decode(StreamEvent.MessageDelta.self, from: eventData) {
                    return .messageDelta(messageDelta)
                }
                return .error("Failed to parse message_delta")
                
            case "content_block_start":
                if let eventData = try? JSONSerialization.data(withJSONObject: json!, options: []),
                   let contentBlockStart = try? JSONDecoder().decode(StreamEvent.ContentBlockStart.self, from: eventData) {
                    return .contentBlockStart(contentBlockStart)
                }
                return .error("Failed to parse content_block_start")
                
            case "content_block_stop":
                if let eventData = try? JSONSerialization.data(withJSONObject: json!, options: []),
                   let contentBlockStop = try? JSONDecoder().decode(StreamEvent.ContentBlockStop.self, from: eventData) {
                    return .contentBlockStop(contentBlockStop)
                }
                return .error("Failed to parse content_block_stop")
                
            case "content_block_delta":
                if let eventData = try? JSONSerialization.data(withJSONObject: json!, options: []),
                   let contentBlockDelta = try? JSONDecoder().decode(StreamEvent.ContentBlockDelta.self, from: eventData) {
                    return .contentBlockDelta(contentBlockDelta)
                }
                return .error("Failed to parse content_block_delta")
                
            case "ping":
                return .ping
                
            default:
                return .error("Unknown event type: \(eventType)")
            }
        } catch {
            return .error("JSON parsing error: \(error.localizedDescription)")
        }
    }
    
    public static func assembleResponse(from events: [StreamEvent]) -> MessagesResponse? {
        var messageStart: StreamEvent.MessageStart?
        var contentBlocks: [ContentBlock] = []
        var finalUsage: MessagesResponse.Usage?
        
        var currentTextBuffer = ""
        var currentIndex = 0
        
        for event in events {
            switch event {
            case .messageStart(let start):
                messageStart = start
                
            case .messageStop(let stop):
                if let usage = stop.usage {
                    finalUsage = usage
                }
                
            case .messageDelta(let delta):
                // Handle message delta - typically contains stop reason updates
                if let usage = delta.usage {
                    finalUsage = usage
                }
                
            case .contentBlockStart(let start):
                if currentIndex < start.index {
                    if !currentTextBuffer.isEmpty {
                        contentBlocks.append(.text(currentTextBuffer))
                        currentTextBuffer = ""
                    }
                    currentIndex = start.index
                }
                
            case .contentBlockDelta(let delta):
                if let text = delta.delta.text {
                    currentTextBuffer += text
                }
                
            case .contentBlockStop:
                if !currentTextBuffer.isEmpty {
                    contentBlocks.append(.text(currentTextBuffer))
                    currentTextBuffer = ""
                }
                
            case .ping, .error:
                break
            }
        }
        
        if !currentTextBuffer.isEmpty {
            contentBlocks.append(.text(currentTextBuffer))
        }
        
        guard let start = messageStart,
              let usage = finalUsage else {
            return nil
        }
        
        let stopReason: MessagesResponse.StopReason?
        if let reason = start.message.stopReason {
            stopReason = MessagesResponse.StopReason(rawValue: reason)
        } else {
            stopReason = nil
        }
        
        return MessagesResponse(
            id: start.message.id,
            type: start.message.type,
            role: start.message.role,
            content: contentBlocks,
            model: start.message.model,
            stopReason: stopReason,
            stopSequence: start.message.stopSequence,
            usage: usage
        )
    }
}