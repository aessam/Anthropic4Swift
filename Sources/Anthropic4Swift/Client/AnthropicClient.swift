import Foundation

public actor AnthropicClient {
    private let httpSession: HTTPSession
    private let configuration: APIConfiguration
    private nonisolated let interceptors: [RequestInterceptor]
    
    public init(apiKey: String, configuration: APIConfiguration? = nil, interceptors: [RequestInterceptor] = []) {
        let config = configuration ?? APIConfiguration(apiKey: apiKey)
        self.configuration = config
        self.httpSession = HTTPSession(configuration: config)
        self.interceptors = interceptors
    }
    
    public func send(_ request: MessagesRequest) async throws -> MessagesResponse {
        // Call interceptors before sending
        for interceptor in interceptors {
            interceptor.willSendRequest(request)
        }
        
        do {
            let httpRequest = try httpSession.createRequest(for: request)
            let (data, _) = try await httpSession.send(request: httpRequest)
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(MessagesResponse.self, from: data)
            
            // Call interceptors after receiving response
            for interceptor in interceptors {
                interceptor.didReceiveResponse(response, for: request)
            }
            
            return response
            
        } catch let error as AnthropicError {
            // Call interceptors on failure
            for interceptor in interceptors {
                interceptor.didFailRequest(request, with: error)
            }
            throw error
        } catch let encodingError as EncodingError {
            let anthropicError = AnthropicError.encodingError(encodingError.localizedDescription)
            for interceptor in interceptors {
                interceptor.didFailRequest(request, with: anthropicError)
            }
            throw anthropicError
        } catch let decodingError as DecodingError {
            let anthropicError = AnthropicError.decodingError(decodingError.localizedDescription)
            for interceptor in interceptors {
                interceptor.didFailRequest(request, with: anthropicError)
            }
            throw anthropicError
        } catch {
            let anthropicError = AnthropicError.networkError(error)
            for interceptor in interceptors {
                interceptor.didFailRequest(request, with: anthropicError)
            }
            throw anthropicError
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
        
        // Call interceptors before streaming
        for interceptor in interceptors {
            interceptor.willSendRequest(streamingRequest)
        }
        
        do {
            let httpRequest = try httpSession.createRequest(for: streamingRequest)
            let capturedRequest = streamingRequest
            let capturedInterceptors = interceptors
            
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        for try await event in httpSession.stream(request: httpRequest) {
                            // Call interceptors for stream events
                            for interceptor in capturedInterceptors {
                                interceptor.didReceiveStreamEvent(event, for: capturedRequest)
                            }
                            continuation.yield(event)
                        }
                        continuation.finish()
                    } catch {
                        for interceptor in capturedInterceptors {
                            interceptor.didFailRequest(capturedRequest, with: error)
                        }
                        continuation.finish(throwing: error)
                    }
                }
            }
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