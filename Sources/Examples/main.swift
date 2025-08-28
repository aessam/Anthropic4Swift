import Foundation
import Anthropic4Swift

// MARK: - Simple Client Usage

func simpleClientExample() async throws {
    // Load client from .env file
    let client = try AnthropicClient.fromEnvironment()
    
    // Simple completion
    let response = try await client.complete("What is the meaning of life?")
    print("Response: \(response)")
    
    // With system prompt
    let philosophicalResponse = try await client.send(
        model: "claude-3-5-sonnet-20241022",
        messages: [.user("What is consciousness?")],
        system: "You are a philosophical AI that thinks deeply about existence."
    )
    print("Philosophical response: \(philosophicalResponse.textContent ?? "")")
}

// MARK: - Agent Usage

func agentExample() async throws {
    // Simple conversational agent from .env
    let agent = try Agent.fromEnvironment(
        systemPrompt: "You are a helpful coding assistant."
    )
    
    let response = try await agent.send("How do I implement a binary search in Swift?")
    print("Agent response: \(response)")
}

// MARK: - Tool Usage

func toolExample() async throws {
    // Define a simple tool
    let weatherTool = SimpleToolFunction(
        name: "get_weather",
        description: "Get current weather for a location",
        parameters: [
            "location": Tool.InputSchema.Property(
                type: "string",
                description: "The city and country, e.g., San Francisco, CA"
            )
        ],
        required: ["location"]
    ) { parameters in
        let location = parameters["location"] as? String ?? "Unknown"
        return "The weather in \(location) is 72°F and sunny."
    }
    
    let agent = try Agent.fromEnvironment(
        systemPrompt: "You are a weather assistant.",
        tools: [weatherTool.tool],
        toolExecutor: FunctionToolExecutor(functions: [weatherTool])
    )
    
    let response = try await agent.send("What's the weather like in Tokyo?")
    print("Weather response: \(response)")
}

// MARK: - Message Builder Usage

func messageBuilderExample() async throws {
    let client = try AnthropicClient.fromEnvironment()
    
    // Using result builder for complex messages
    let userMessage = UserMessage {
        "Please analyze this image:"
        // Note: In real usage, you'd load an actual image
        // Image(cgImage, maxSize: CGSize(width: 1024, height: 1024))
        "What do you see?"
    }
    
    let response = try await client.send(
        messages: [userMessage.message]
    )
    print("Image analysis: \(response.textContent ?? "")")
}

// MARK: - Streaming Usage

@available(macOS 10.15, *)
func streamingExample() async throws {
    let client = try AnthropicClient.fromEnvironment()
    
    print("Streaming response:")
    for try await chunk in client.streamComplete("Write a haiku about Swift programming") {
        print(chunk, terminator: "")
    }
    print("\n")
}

// MARK: - Observability Usage

func observabilityExample() async throws {
    let client = try AnthropicClient.fromEnvironment()
    
    // You can add interceptors for debugging and metrics
    let _ = DebugInterceptor()
    let _ = MetricsInterceptor()
    
    // In a real implementation, you'd add these to the client
    // This is just showing the API structure
    
    let response = try await client.complete("Hello, Claude!")
    print("Response with observability: \(response)")
    
    // Get metrics
    let metrics = await MetricsCollector.shared.getMetrics()
    print(metrics.summary())
}

// MARK: - Error Handling Example

func errorHandlingExample() async {
    // Example with invalid configuration
    let client = AnthropicClient(apiKey: "invalid-key")
    
    do {
        let response = try await client.complete("Test message")
        print("Unexpected success: \(response)")
    } catch let error as AnthropicError {
        switch error {
        case .apiError(let code, let message):
            print("API Error \(code): \(message)")
        case .networkError(let underlying):
            print("Network Error: \(underlying.localizedDescription)")
        case .invalidAPIKey:
            print("Invalid API key provided")
        default:
            print("Other Anthropic error: \(error.description)")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
}

// MARK: - Main Example Runner

@main
struct Examples {
    static func main() async {
        print("Anthropic4Swift Examples")
        print("========================")
        
        // Note: Create a .env file with ANTHROPIC_API_KEY=your-actual-key to run these examples
        
        do {
            print("\n1. Simple Client Example:")
            try await simpleClientExample()
            
            print("\n2. Agent Example:")
            try await agentExample()
            
            print("\n3. Tool Example:")
            try await toolExample()
            
            print("\n4. Message Builder Example:")
            try await messageBuilderExample()
            
            print("\n5. Streaming Example:")
            if #available(macOS 10.15, *) {
                try await streamingExample()
            }
            
            print("\n6. Observability Example:")
            try await observabilityExample()
            
            print("\n7. Error Handling Example:")
            await errorHandlingExample()
            
        } catch {
            print("Example failed with error: \(error)")
        }
        
        print("\nAll examples completed!")
    }
}
