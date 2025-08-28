# Anthropic4Swift

A Swift package for interacting with Anthropic's Claude API. Built with modern Swift concurrency, persistent HTTP connections, and a powerful agents layer.

## Features

- 🚀 **Persistent HTTP connections** - Reuse connections to avoid ~400ms connection overhead
- 🤖 **Agent abstraction** - High-level agents with automatic tool loop handling
- 🛠️ **Tool use support** - Define custom tools with automatic execution
- 📸 **Multimodal support** - Text and images using CoreGraphics
- 🌊 **Streaming responses** - Real-time response streaming with AsyncStream
- 📊 **Observability** - Built-in logging and metrics collection
- 🎯 **Result builders** - Clean DSL for building complex messages
- 🔒 **Type safety** - Strong typing with Codable models throughout
- ⚡ **Swift concurrency** - Built with async/await and actors

## Requirements

- macOS 12.0+ / iOS 15.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add this to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Anthropic4Swift", from: "1.0.0")
]
```

Or add it through Xcode: File → Add Package Dependencies → Enter repository URL

## Quick Start

### Basic Usage

```swift
import Anthropic4Swift

// Option 1: Direct API key
let client = AnthropicClient(apiKey: "your-api-key")

// Option 2: Load from .env file
let client = try AnthropicClient.fromEnvironment()

// Simple completion
let response = try await client.complete("What is Swift?")
print(response)

// With options
let response = try await client.send(
    model: "claude-3-5-sonnet-20241022",
    messages: [.user("Explain quantum computing")],
    maxTokens: 1000,
    system: "You are a physics professor."
)
```

### Environment Configuration

Create a `.env` file in your project root:

```bash
# .env
ANTHROPIC_API_KEY=your-actual-api-key-here
```

Then use the convenience methods:

```swift
// Load client from environment
let client = try AnthropicClient.fromEnvironment()

// Load agent from environment
let agent = try Agent.fromEnvironment(systemPrompt: "You are helpful.")
```

### Agent Usage

```swift
// Simple conversational agent
let agent = try Agent.fromEnvironment(
    systemPrompt: "You are a helpful coding assistant."
)

let response = try await agent.send("How do I sort an array in Swift?")
```

### Tool Usage

```swift
// Define a custom tool
let calculatorTool = SimpleToolFunction(
    name: "calculate",
    description: "Perform basic math operations",
    parameters: [
        "expression": Tool.InputSchema.Property(
            type: "string", 
            description: "Math expression to evaluate"
        )
    ],
    required: ["expression"]
) { parameters in
    let expression = parameters["expression"] as? String ?? ""
    // Your calculation logic here
    return "Result: 42"
}

let agent = Agent.withTools(
    apiKey: "your-api-key",
    functions: [calculatorTool]
)

let response = try await agent.send("What is 2 + 2?")
// Agent will automatically use the tool and provide the result
```

### Multimodal Messages

```swift
let userMessage = UserMessage {
    Text("What's in this image?")
    Image(cgImage) // Your CGImage
    Text("Please describe it in detail.")
}

let response = try await client.send(messages: [userMessage.message])
```

### Streaming Responses

```swift
for try await chunk in client.streamComplete("Write a story about AI") {
    print(chunk, terminator: "")
}
```

## Architecture

### Core Components

1. **AnthropicClient** - Main HTTP client with persistent connections
2. **Agent** - High-level abstraction with conversation management and tool loops  
3. **Conversation** - Manages message history and context
4. **Tool system** - Define and execute custom tools
5. **Observability** - Logging, metrics, and debugging support

### Request Flow

```
User Input → Agent → Conversation → AnthropicClient → Anthropic API
                ↓
        Tool Execution (if needed)
                ↓
        Response Processing → Tool Results → Continue until complete
```

### Tool Loop

The agent automatically handles multi-turn tool interactions:

1. Send message to Claude
2. Claude responds with tool_use
3. Execute tools locally  
4. Send tool results back to Claude
5. Claude provides final response
6. Repeat if more tools needed

## Advanced Usage

### Custom Tool Executor

```swift
struct MyToolExecutor: ToolExecutor {
    func execute(_ toolUse: ContentBlock.ToolUseBlock) async throws -> String {
        switch toolUse.name {
        case "database_query":
            return await performDatabaseQuery(toolUse.input)
        case "send_email":
            return await sendEmail(toolUse.input)
        default:
            return "Unknown tool: \(toolUse.name)"
        }
    }
}

let agent = Agent(
    apiKey: "your-api-key",
    tools: myTools,
    toolExecutor: MyToolExecutor()
)
```

### Observability

```swift
// Enable debugging
let debugInterceptor = DebugInterceptor()

// Track metrics
let metrics = await MetricsCollector.shared.getMetrics()
print(metrics.summary())

// Custom logging
let logger = Logger(subsystem: "MyApp", category: "AI")
logger.info("Starting AI conversation")
```

### Error Handling

```swift
do {
    let response = try await client.complete("Hello")
} catch let error as AnthropicError {
    switch error {
    case .apiError(let code, let message):
        print("API Error \(code): \(message)")
    case .networkError(let error):
        print("Network Error: \(error)")
    case .invalidAPIKey:
        print("Invalid API key")
    default:
        print("Other error: \(error)")
    }
}
```

## Models

All current Claude models are supported:

- `claude-3-5-sonnet-20241022` (default)
- `claude-3-5-haiku-20241022`
- `claude-3-opus-20240229`

## API Reference

### AnthropicClient

- `init(apiKey: String)`
- `complete(_ prompt: String) async throws -> String`
- `send(_ request: MessagesRequest) async throws -> MessagesResponse`
- `stream(_ request: MessagesRequest) -> AsyncThrowingStream<StreamEvent, Error>`

### Agent

- `Agent.conversation(apiKey: String, systemPrompt: String?) -> Agent`
- `Agent.withTools(apiKey: String, functions: [ToolFunction]) -> Agent`
- `send(_ message: String) async throws -> String`
- `clearConversation()`

### Result Builders

- `UserMessage { }` - Build multimodal messages
- `Text(_ string: String)` - Add text content
- `Image(_ cgImage: CGImage)` - Add image content

## Performance

- **Persistent HTTP connections** save ~400ms per request
- **Efficient image processing** with CoreGraphics
- **Minimal memory overhead** with streaming support
- **Thread-safe** with proper actor isolation

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Support

- Documentation: [Link to docs]
- Issues: [GitHub Issues](https://github.com/yourusername/Anthropic4Swift/issues)
- Discussions: [GitHub Discussions](https://github.com/yourusername/Anthropic4Swift/discussions)

## Running Examples

The package includes an executable target with examples:

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/Anthropic4Swift
cd Anthropic4Swift

# 2. Create .env file from example
cp .env.example .env
# Edit .env and add your API key

# 3. Run examples
swift run Examples
```

## Changelog

### 1.0.0
- Initial release
- Core API client with persistent connections
- Agent abstraction with tool loop  
- Multimodal support (text + images)
- Streaming responses
- Observability layer
- Result builders for message construction
- .env file support
- Executable examples target