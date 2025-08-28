import Foundation

public protocol RequestInterceptor: Sendable {
    func willSendRequest(_ request: MessagesRequest)
    func didReceiveResponse(_ response: MessagesResponse, for request: MessagesRequest)
    func didFailRequest(_ request: MessagesRequest, with error: Error)
    func didReceiveStreamEvent(_ event: StreamEvent, for request: MessagesRequest)
}

public extension RequestInterceptor {
    func willSendRequest(_ request: MessagesRequest) {}
    func didReceiveResponse(_ response: MessagesResponse, for request: MessagesRequest) {}
    func didFailRequest(_ request: MessagesRequest, with error: Error) {}
    func didReceiveStreamEvent(_ event: StreamEvent, for request: MessagesRequest) {}
}

public struct InterceptorChain: RequestInterceptor {
    private let interceptors: [RequestInterceptor]
    
    public init(interceptors: [RequestInterceptor]) {
        self.interceptors = interceptors
    }
    
    public func willSendRequest(_ request: MessagesRequest) {
        interceptors.forEach { $0.willSendRequest(request) }
    }
    
    public func didReceiveResponse(_ response: MessagesResponse, for request: MessagesRequest) {
        interceptors.forEach { $0.didReceiveResponse(response, for: request) }
    }
    
    public func didFailRequest(_ request: MessagesRequest, with error: Error) {
        interceptors.forEach { $0.didFailRequest(request, with: error) }
    }
    
    public func didReceiveStreamEvent(_ event: StreamEvent, for request: MessagesRequest) {
        interceptors.forEach { $0.didReceiveStreamEvent(event, for: request) }
    }
}

public struct DebugInterceptor: RequestInterceptor {
    private let logger: Logger
    
    public init(logger: Logger = .shared) {
        self.logger = logger
    }
    
    public func willSendRequest(_ request: MessagesRequest) {
        logger.debug("🚀 Sending request to model: \(request.model)")
        logger.debug("📝 Messages count: \(request.messages.count)")
        logger.debug("🛠 Tools count: \(request.tools?.count ?? 0)")
        logger.debug("🎛 Max tokens: \(request.maxTokens)")
        if let temp = request.temperature {
            logger.debug("🌡 Temperature: \(temp)")
        }
    }
    
    public func didReceiveResponse(_ response: MessagesResponse, for request: MessagesRequest) {
        logger.debug("✅ Received response: \(response.id)")
        logger.debug("⏱ Input tokens: \(response.usage.inputTokens)")
        logger.debug("📤 Output tokens: \(response.usage.outputTokens)")
        logger.debug("💰 Estimated cost: $\(String(format: "%.4f", response.usage.estimatedCost))")
        if let stopReason = response.stopReason {
            logger.debug("🛑 Stop reason: \(stopReason.rawValue)")
        }
        if !response.toolUses.isEmpty {
            logger.debug("🔧 Tool uses: \(response.toolUses.map { $0.name }.joined(separator: ", "))")
        }
    }
    
    public func didFailRequest(_ request: MessagesRequest, with error: Error) {
        logger.error("❌ Request failed: \(error.localizedDescription)")
    }
    
    public func didReceiveStreamEvent(_ event: StreamEvent, for request: MessagesRequest) {
        switch event {
        case .messageStart:
            logger.debug("🌊 Stream started")
        case .messageStop(let stop):
            logger.debug("🏁 Stream finished - Total tokens: \(stop.usage.totalTokens)")
        case .contentBlockDelta(let delta):
            if let text = delta.delta.text {
                logger.debug("📝 Delta: \(text.prefix(50))\(text.count > 50 ? "..." : "")")
            }
        case .error(let error):
            logger.error("🌊❌ Stream error: \(error)")
        default:
            break
        }
    }
}

public struct MetricsInterceptor: RequestInterceptor {
    private let metricsCollector: MetricsCollector
    
    public init(metricsCollector: MetricsCollector = .shared) {
        self.metricsCollector = metricsCollector
    }
    
    public func willSendRequest(_ request: MessagesRequest) {
        Task {
            await metricsCollector.recordRequestStarted(model: request.model)
        }
    }
    
    public func didReceiveResponse(_ response: MessagesResponse, for request: MessagesRequest) {
        Task {
            await metricsCollector.recordRequestCompleted(
                model: request.model,
                inputTokens: response.usage.inputTokens,
                outputTokens: response.usage.outputTokens,
                cost: response.usage.estimatedCost
            )
        }
    }
    
    public func didFailRequest(_ request: MessagesRequest, with error: Error) {
        Task {
            await metricsCollector.recordRequestFailed(model: request.model, error: error)
        }
    }
}