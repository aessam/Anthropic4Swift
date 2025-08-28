import Foundation
import os.log

public struct Logger: Sendable {
    private let osLog: OSLog
    
    public static let shared = Logger()
    
    public init(subsystem: String = "com.anthropic4swift", category: String = "AnthropicClient") {
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }
    
    public func debug(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: osLog, type: .debug, message)
        #endif
    }
    
    public func info(_ message: String) {
        os_log("%{public}@", log: osLog, type: .info, message)
    }
    
    public func error(_ message: String) {
        os_log("%{public}@", log: osLog, type: .error, message)
    }
    
    public func fault(_ message: String) {
        os_log("%{public}@", log: osLog, type: .fault, message)
    }
}

public struct ConsoleLogger: Sendable {
    public static let shared = ConsoleLogger()
    
    public init() {}
    
    public func debug(_ message: String) {
        #if DEBUG
        print("🔍 DEBUG: \(message)")
        #endif
    }
    
    public func info(_ message: String) {
        print("ℹ️ INFO: \(message)")
    }
    
    public func error(_ message: String) {
        print("❌ ERROR: \(message)")
    }
    
    public func fault(_ message: String) {
        print("💥 FAULT: \(message)")
    }
}