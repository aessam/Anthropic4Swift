import Foundation

final class HTTPSession: NSObject, @unchecked Sendable {
    let session: URLSession
    private let configuration: APIConfiguration
    
    init(configuration: APIConfiguration) {
        self.configuration = configuration
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout
        
        sessionConfig.httpAdditionalHeaders = [
            "Connection": "keep-alive",
            "Keep-Alive": "timeout=120, max=1000"
        ]
        
        sessionConfig.httpMaximumConnectionsPerHost = 6
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.urlCache = nil
        
        self.session = URLSession(configuration: sessionConfig)
        super.init()
    }
    
    func createRequest(for messagesRequest: MessagesRequest) throws -> URLRequest {
        var request = URLRequest(url: configuration.messagesURL)
        request.httpMethod = "POST"
        
        for (key, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let jsonData = try JSONEncoder().encode(messagesRequest)
        request.httpBody = jsonData
        
        return request
    }
    
    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse("Expected HTTPURLResponse")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AnthropicError.apiError(httpResponse.statusCode, message)
            }
            throw AnthropicError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8))
        }
        
        return (data, httpResponse)
    }
    
    func stream(request: URLRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        return AsyncThrowingStream { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.finish(throwing: AnthropicError.networkError(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.finish(throwing: AnthropicError.invalidResponse("Expected HTTPURLResponse"))
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) }
                    continuation.finish(throwing: AnthropicError.httpError(httpResponse.statusCode, errorMessage))
                    return
                }
                
                continuation.finish()
            }
            
            let delegate = StreamingDelegate(continuation: continuation)
            task.delegate = delegate
            task.resume()
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

private final class StreamingDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    private var buffer = Data()
    
    init(continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation) {
        self.continuation = continuation
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        
        while let newlineRange = buffer.range(of: Data("\n".utf8)) {
            let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
            buffer.removeSubrange(0..<newlineRange.upperBound)
            
            if let line = String(data: lineData, encoding: .utf8),
               !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let event = StreamingResponseParser.parseEvent(from: line) {
                    continuation.yield(event)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation.finish(throwing: AnthropicError.networkError(error))
        } else {
            continuation.finish()
        }
    }
}

public enum AnthropicError: Error, CustomStringConvertible {
    case invalidAPIKey
    case invalidResponse(String)
    case apiError(Int, String)
    case httpError(Int, String?)
    case encodingError(String)
    case decodingError(String)
    case networkError(Error)
    
    public var description: String {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .httpError(let code, let message):
            return "HTTP error (\(code)): \(message ?? "Unknown error")"
        case .encodingError(let message):
            return "Encoding error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}