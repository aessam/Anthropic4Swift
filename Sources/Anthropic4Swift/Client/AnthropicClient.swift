import Foundation

public actor AnthropicClient {
    private let httpSession: HTTPSession
    private let configuration: APIConfiguration
    
    public init(apiKey: String, configuration: APIConfiguration? = nil) {
        let config = configuration ?? APIConfiguration(apiKey: apiKey)
        self.configuration = config
        self.httpSession = HTTPSession(configuration: config)
    }
    
    public func send(_ request: MessagesRequest) async throws -> MessagesResponse {
        do {
            let httpRequest = try httpSession.createRequest(for: request)
            let (data, _) = try await httpSession.send(request: httpRequest)
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(MessagesResponse.self, from: data)
            return response
            
        } catch let error as AnthropicError {
            throw error
        } catch let encodingError as EncodingError {
            throw AnthropicError.encodingError(encodingError.localizedDescription)
        } catch let decodingError as DecodingError {
            throw AnthropicError.decodingError(decodingError.localizedDescription)
        } catch {
            throw AnthropicError.networkError(error)
        }
    }
    
    public func send(
        model: String = MessagesRequest.defaultModel,
        messages: [Message],
        maxTokens: Int = 4096,
        system: String? = nil,
        tools: [Tool]? = nil,
        temperature: Double? = nil
    ) async throws -> MessagesResponse {
        let request = MessagesRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            system: system,
            tools: tools,
            temperature: temperature
        )
        return try await send(request)
    }
    
    public func complete(
        _ prompt: String,
        model: String = MessagesRequest.defaultModel,
        maxTokens: Int = 4096,
        system: String? = nil,
        temperature: Double? = nil
    ) async throws -> String {
        let request = MessagesRequest(
            model: model,
            messages: [.user(prompt)],
            maxTokens: maxTokens,
            system: system,
            temperature: temperature
        )
        
        let response = try await send(request)
        return response.textContent ?? ""
    }
    
    nonisolated public func stream(_ request: MessagesRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        var streamingRequest = request
        
        if streamingRequest.stream != true {
            streamingRequest = MessagesRequest(
                model: streamingRequest.model,
                messages: streamingRequest.messages,
                maxTokens: streamingRequest.maxTokens,
                system: streamingRequest.system?.toText(),
                tools: streamingRequest.tools,
                temperature: streamingRequest.temperature,
                topP: streamingRequest.topP,
                topK: streamingRequest.topK,
                stream: true,
                stopSequences: streamingRequest.stopSequences,
                metadata: streamingRequest.metadata
            )
        }
        
        do {
            let httpRequest = try httpSession.createRequest(for: streamingRequest)
            return httpSession.stream(request: httpRequest)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }
    
    nonisolated public func streamComplete(
        _ prompt: String,
        model: String = MessagesRequest.defaultModel,
        maxTokens: Int = 4096,
        system: String? = nil,
        temperature: Double? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let request = MessagesRequest(
            model: model,
            messages: [.user(prompt)],
            maxTokens: maxTokens,
            system: system,
            temperature: temperature,
            stream: true
        )
        
        return AsyncThrowingStream { continuation in
            Task {
                var textBuffer = ""
                
                do {
                    for try await event in stream(request) {
                        switch event {
                        case .contentBlockDelta(let delta):
                            if let text = delta.delta.text {
                                textBuffer += text
                                continuation.yield(text)
                            }
                        case .messageStop:
                            continuation.finish()
                            return
                        case .error(let errorMessage):
                            continuation.finish(throwing: AnthropicError.apiError(500, errorMessage))
                            return
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}