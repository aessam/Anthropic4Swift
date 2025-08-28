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
    
    // MARK: - Convenience Methods for Common Endpoints
    
    /// Configuration for AWS Bedrock
    public static func bedrock(apiKey: String, region: String = "us-east-1") -> APIConfiguration {
        let baseURL = URL(string: "https://bedrock-runtime.\(region).amazonaws.com")!
        return APIConfiguration(apiKey: apiKey, baseURL: baseURL)
    }
    
    /// Configuration for Google Cloud Vertex AI
    public static func vertexAI(apiKey: String, projectId: String, region: String = "us-central1") -> APIConfiguration {
        let baseURL = URL(string: "https://\(region)-aiplatform.googleapis.com/v1/projects/\(projectId)/locations/\(region)")!
        return APIConfiguration(apiKey: apiKey, baseURL: baseURL)
    }
    
    /// Configuration for Azure OpenAI
    public static func azure(apiKey: String, endpoint: String) -> APIConfiguration {
        let baseURL = URL(string: endpoint)!
        return APIConfiguration(apiKey: apiKey, baseURL: baseURL)
    }
    
    /// Configuration for custom endpoint
    public static func custom(apiKey: String, baseURL: String) -> APIConfiguration {
        let url = URL(string: baseURL)!
        return APIConfiguration(apiKey: apiKey, baseURL: url)
    }
}