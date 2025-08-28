import Foundation

public actor MetricsCollector {
    public static let shared = MetricsCollector()
    
    private var requestCounts: [String: Int] = [:]
    private var tokenUsage: [String: (input: Int, output: Int)] = [:]
    private var totalCost: Double = 0
    private var errorCounts: [String: Int] = [:]
    private var requestTimes: [String: [TimeInterval]] = [:]
    
    public init() {}
    
    public func recordRequestStarted(model: String) {
        requestCounts[model, default: 0] += 1
    }
    
    public func recordRequestCompleted(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cost: Double
    ) {
        let currentUsage = tokenUsage[model, default: (0, 0)]
        tokenUsage[model] = (
            input: currentUsage.input + inputTokens,
            output: currentUsage.output + outputTokens
        )
        totalCost += cost
    }
    
    public func recordRequestFailed(model: String, error: Error) {
        let errorKey = "\(model):\(type(of: error))"
        errorCounts[errorKey, default: 0] += 1
    }
    
    public func getMetrics() -> Metrics {
        Metrics(
            requestCounts: requestCounts,
            tokenUsage: tokenUsage,
            totalCost: totalCost,
            errorCounts: errorCounts
        )
    }
    
    public func reset() {
        requestCounts.removeAll()
        tokenUsage.removeAll()
        totalCost = 0
        errorCounts.removeAll()
        requestTimes.removeAll()
    }
}

public struct Metrics: Sendable {
    public let requestCounts: [String: Int]
    public let tokenUsage: [String: (input: Int, output: Int)]
    public let totalCost: Double
    public let errorCounts: [String: Int]
    
    public var totalRequests: Int {
        requestCounts.values.reduce(0, +)
    }
    
    public var totalInputTokens: Int {
        tokenUsage.values.reduce(0) { $0 + $1.input }
    }
    
    public var totalOutputTokens: Int {
        tokenUsage.values.reduce(0) { $0 + $1.output }
    }
    
    public var totalTokens: Int {
        totalInputTokens + totalOutputTokens
    }
    
    public var totalErrors: Int {
        errorCounts.values.reduce(0, +)
    }
    
    public func summary() -> String {
        var lines: [String] = []
        lines.append("📊 Anthropic4Swift Metrics Summary")
        lines.append("──────────────────────────────────")
        lines.append("Total Requests: \(totalRequests)")
        lines.append("Total Tokens: \(totalTokens) (Input: \(totalInputTokens), Output: \(totalOutputTokens))")
        lines.append("Total Cost: $\(String(format: "%.4f", totalCost))")
        
        if totalErrors > 0 {
            lines.append("Total Errors: \(totalErrors)")
        }
        
        if !requestCounts.isEmpty {
            lines.append("\nRequests by Model:")
            for (model, count) in requestCounts.sorted(by: { $0.value > $1.value }) {
                lines.append("  \(model): \(count)")
            }
        }
        
        if !tokenUsage.isEmpty {
            lines.append("\nToken Usage by Model:")
            for (model, usage) in tokenUsage.sorted(by: { $0.value.input + $0.value.output > $1.value.input + $1.value.output }) {
                lines.append("  \(model): \(usage.input + usage.output) total (\(usage.input) in, \(usage.output) out)")
            }
        }
        
        return lines.joined(separator: "\n")
    }
}