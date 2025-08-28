import Foundation

public struct EnvironmentLoader {
    public static func loadFromFile(_ path: String = ".env") throws -> [String: String] {
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        let envPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(path).path
        
        guard fileManager.fileExists(atPath: envPath) else {
            throw EnvironmentError.fileNotFound(envPath)
        }
        
        let content = try String(contentsOfFile: envPath, encoding: .utf8)
        return parseEnvironmentFile(content)
    }
    
    public static func loadAPIKey(from path: String = ".env") throws -> String {
        let env = try loadFromFile(path)
        
        if let apiKey = env["ANTHROPIC_API_KEY"] {
            return apiKey
        } else if let apiKey = env["CLAUDE_API_KEY"] {
            return apiKey
        } else {
            throw EnvironmentError.missingAPIKey
        }
    }
    
    public static func configure(from path: String = ".env") throws -> APIConfiguration {
        let env = try loadFromFile(path)
        let apiKey = try loadAPIKey(from: path)
        
        var config = APIConfiguration(apiKey: apiKey)
        
        if let baseURL = env["ANTHROPIC_BASE_URL"],
           let url = URL(string: baseURL) {
            config = APIConfiguration(
                apiKey: apiKey,
                baseURL: url,
                version: config.version,
                timeout: config.timeout
            )
        }
        
        return config
    }
    
    private static func parseEnvironmentFile(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse KEY=VALUE
            if let equalIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: equalIndex)...])
                
                // Remove quotes if present
                let cleanValue = removeQuotes(from: value)
                result[key] = cleanValue
            }
        }
        
        return result
    }
    
    private static func removeQuotes(from string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        
        return trimmed
    }
}

public enum EnvironmentError: Error, LocalizedError {
    case fileNotFound(String)
    case missingAPIKey
    case invalidFormat(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Environment file not found at path: \(path)"
        case .missingAPIKey:
            return "Missing API key. Please set ANTHROPIC_API_KEY or CLAUDE_API_KEY in your .env file"
        case .invalidFormat(let line):
            return "Invalid format in environment file at line: \(line)"
        }
    }
}

// MARK: - Convenience Extensions

extension AnthropicClient {
    /// Create client from .env file
    public static func fromEnvironment(_ path: String = ".env", interceptors: [RequestInterceptor] = []) throws -> AnthropicClient {
        let config = try EnvironmentLoader.configure(from: path)
        return AnthropicClient(apiKey: config.apiKey, configuration: config, interceptors: interceptors)
    }
}

extension Agent {
    /// Create agent from .env file
    public static func fromEnvironment(
        _ path: String = ".env",
        systemPrompt: String? = nil,
        tools: [Tool] = [],
        toolExecutor: ToolExecutor? = nil,
        model: String = MessagesRequest.defaultModel
    ) throws -> Agent {
        let apiKey = try EnvironmentLoader.loadAPIKey(from: path)
        return Agent(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            tools: tools,
            toolExecutor: toolExecutor,
            model: model
        )
    }
}