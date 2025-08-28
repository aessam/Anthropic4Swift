import Foundation

public struct APIConfiguration: Sendable {
    public let apiKey: String
    public let baseURL: URL
    public let version: String
    public let timeout: TimeInterval
    
    public static let anthropicVersion = "2023-06-01"
    public static let defaultBaseURL = URL(string: "https://api.anthropic.com")!
    public static let defaultTimeout: TimeInterval = 120
    
    public init(
        apiKey: String,
        baseURL: URL = defaultBaseURL,
        version: String = anthropicVersion,
        timeout: TimeInterval = defaultTimeout
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.version = version
        self.timeout = timeout
    }
    
    public var messagesURL: URL {
        baseURL.appendingPathComponent("v1/messages")
    }
    
    public var headers: [String: String] {
        [
            "x-api-key": apiKey,
            "anthropic-version": version,
            "content-type": "application/json",
            "connection": "keep-alive"
        ]
    }
}