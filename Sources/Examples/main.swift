import Foundation
import CoreGraphics
import Anthropic4Swift

// MARK: - Simple Client Usage

func simpleClientExample() async throws {
    // Load client from .env file
    let client = try AnthropicClient.fromEnvironment()
    
    // Simple completion
    print("\u{001B}[36m📝 Prompt: What is the meaning of life?\u{001B}[0m")
    let response = try await client.complete("What is the meaning of life?")
    print("\u{001B}[32m🤖 Response:\u{001B}[0m \(response)")
    
    // With system prompt
    print("\u{001B}[36m📝 Prompt: What is consciousness?\u{001B}[0m")
    print("\u{001B}[33m🎭 System: You are a philosophical AI that thinks deeply about existence.\u{001B}[0m")
    let philosophicalResponse = try await client.send(
        model: "claude-3-5-sonnet-20241022",
        messages: [.user("What is consciousness?")],
        system: "You are a philosophical AI that thinks deeply about existence."
    )
    print("\u{001B}[32m🤖 Response:\u{001B}[0m \(philosophicalResponse.textContent ?? "")")
}

// MARK: - Agent Usage

func agentExample() async throws {
    // Simple conversational agent from .env
    let agent = try Agent.fromEnvironment(
        systemPrompt: "You are a helpful coding assistant."
    )
    
    print("\u{001B}[33m🎭 System: You are a helpful coding assistant.\u{001B}[0m")
    print("\u{001B}[36m📝 Prompt: How do I implement a binary search in Swift?\u{001B}[0m")
    let response = try await agent.send("How do I implement a binary search in Swift?")
    print("\u{001B}[32m🤖 Response:\u{001B}[0m \(response)")
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
        print("\u{001B}[35m🔧 Tool Called: get_weather(location: \"\(location)\")\u{001B}[0m")
        return "The weather in \(location) is 72°F and sunny."
    }
    
    let agent = try Agent.fromEnvironment(
        systemPrompt: "You are a weather assistant.",
        tools: [weatherTool.tool],
        toolExecutor: FunctionToolExecutor(functions: [weatherTool])
    )
    
    print("\u{001B}[33m🎭 System: You are a weather assistant.\u{001B}[0m")
    print("\u{001B}[36m📝 Prompt: What's the weather like in Tokyo?\u{001B}[0m")
    let response = try await agent.send("What's the weather like in Tokyo?")
    print("\u{001B}[32m🤖 Response:\u{001B}[0m \(response)")
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
    
    print("\u{001B}[36m📝 Prompt: Please analyze this image: What do you see?\u{001B}[0m")
    let response = try await client.send(
        messages: [userMessage.message]
    )
    print("\u{001B}[32m🤖 Response:\u{001B}[0m \(response.textContent ?? "")")
}

// MARK: - Streaming Usage

@available(macOS 10.15, *)
func streamingExample() async throws {
    let client = try AnthropicClient.fromEnvironment()
    
    print("\u{001B}[36m📝 Prompt: Write a haiku about Swift programming\u{001B}[0m")
    print("\u{001B}[32m🤖 Streaming Response:\u{001B}[0m ")
    for try await chunk in client.streamComplete("Write a haiku about Swift programming") {
        print(chunk, terminator: "")
    }
    print("\n")
}

// MARK: - Observability Usage

func observabilityExample() async throws {
    // Create interceptors
    let debugInterceptor = DebugInterceptor()
    let metricsInterceptor = MetricsInterceptor()
    
    // Create client with interceptors
    let client = try AnthropicClient.fromEnvironment(interceptors: [debugInterceptor, metricsInterceptor])
    
    print("\u{001B}[36m📝 Prompt: Hello, Claude!\u{001B}[0m")
    let response = try await client.complete("Hello, Claude!")
    print("\u{001B}[32m🤖 Response:\u{001B}[0m \(response)")
    
    // Get metrics
    let metrics = await MetricsCollector.shared.getMetrics()
    print("\u{001B}[34m📊 Metrics:\u{001B}[0m")
    print(metrics.summary())
}

// MARK: - Image Testing Example

func imageTestingExample() async throws {
    let client = try AnthropicClient.fromEnvironment()
    
    print("\n🖼️  Testing Image Analysis with Various Test Images:")
    print("====================================================")
    
    // Test 1: TV Test Pattern - Classic technical test image
    await testSingleImage(
        client: client,
        imagePath: "TestData/Philips_PM5544.svg.png",
        prompt: "What is this image? What type of pattern or test is this?",
        description: "TV Test Pattern"
    )
    
    // Test 2: App Store Screenshot - Real-world UI
    await testSingleImage(
        client: client,
        imagePath: "TestData/Sample.png", 
        prompt: "Describe this mobile app interface. What app is being advertised?",
        description: "Mobile App Screenshot"
    )
    
    // Test 3: Simple Test Icon - Clean vector-style image
    await testSingleImage(
        client: client,
        imagePath: "TestData/pngtree-test-orange-icon-sign-test-testing-vector-png-image_15029880.png",
        prompt: "What does this icon say and what is its design style?",
        description: "Test Icon"
    )
    
    // Test 4: Multimodal with Result Builder
    print("\n\u{001B}[95m🔄 Testing Result Builder with Image + Text:\u{001B}[0m")
    print("------------------------------")
    
    let multimodalMessage = UserMessage {
        "Please analyze this test pattern image and tell me:"
        "1. What type of test this is"
        "2. What the different colored sections are for"  
        "3. Why this pattern is useful for testing"
        Image(loadImageAsCGImage("TestData/Philips_PM5544.svg.png"))
    }
    
    print("\u{001B}[36m📝 Prompt: Analyze test pattern with 3 questions\u{001B}[0m")
    do {
        let response = try await client.send(messages: [multimodalMessage.message])
        print("\u{001B}[32m🤖 Detailed Analysis:\u{001B}[0m \(response.textContent ?? "No response")")
    } catch {
        print("\u{001B}[31m❌ Multimodal test failed: \(error)\u{001B}[0m")
    }
}

func testSingleImage(client: AnthropicClient, imagePath: String, prompt: String, description: String) async {
    print("\n\u{001B}[95m📸 Testing: \(description)\u{001B}[0m")
    print("\u{001B}[36m📝 Prompt: \(prompt)\u{001B}[0m")
    
    do {
        let cgImage = loadImageAsCGImage(imagePath)
        let message = UserMessage {
            prompt
            Image(cgImage)
        }
        
        let response = try await client.send(messages: [message.message])
        print("\u{001B}[32m🤖 Response:\u{001B}[0m \(response.textContent ?? "No response")")
        print("\u{001B}[34m💰 Cost: $\(String(format: "%.4f", response.usage.estimatedCost))\u{001B}[0m")
        print("\u{001B}[34m🔢 Tokens: \(response.usage.totalTokens) (\(response.usage.inputTokens) in, \(response.usage.outputTokens) out)\u{001B}[0m")
        
    } catch {
        print("\u{001B}[31m❌ Failed to analyze \(description): \(error)\u{001B}[0m")
    }
}

func loadImageAsCGImage(_ path: String) -> CGImage {
    let fullPath = "/Volumes/MyUniverse/LLM/Anthropic4Swift/" + path
    let url = URL(fileURLWithPath: fullPath)
    
    guard let imageData = try? Data(contentsOf: url),
          let dataProvider = CGDataProvider(data: imageData as CFData),
          let cgImage = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) ??
                        CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
        
        // Return a simple 1x1 red pixel as fallback
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapContext = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        bitmapContext.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        bitmapContext.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return bitmapContext.makeImage()!
    }
    
    return cgImage
}

// MARK: - Custom URL/Endpoint Example

func customURLExample() async throws {
    print("\u{001B}[95m🌐 Testing Custom URLs/Endpoints:\u{001B}[0m")
    print("===================================")
    
    // Example 1: Direct URL configuration
    print("\n1. Using direct URL configuration:")
    let customConfig = APIConfiguration.custom(
        apiKey: "test-key", 
        baseURL: "https://api.custom-claude.com"
    )
    let _ = AnthropicClient(apiKey: "test-key", configuration: customConfig)
    print("\u{001B}[34m🔗 Custom endpoint: \(customConfig.baseURL.absoluteString)\u{001B}[0m")
    
    // Example 2: AWS Bedrock configuration
    print("\n2. AWS Bedrock configuration:")
    let bedrockConfig = APIConfiguration.bedrock(apiKey: "aws-key", region: "us-west-2")
    let _ = AnthropicClient(apiKey: "aws-key", configuration: bedrockConfig)
    print("\u{001B}[34m🔗 Bedrock endpoint: \(bedrockConfig.baseURL.absoluteString)\u{001B}[0m")
    
    // Example 3: Google Cloud Vertex AI configuration  
    print("\n3. Google Cloud Vertex AI configuration:")
    let vertexConfig = APIConfiguration.vertexAI(
        apiKey: "gcp-key",
        projectId: "my-project",
        region: "us-central1"
    )
    let _ = AnthropicClient(apiKey: "gcp-key", configuration: vertexConfig)
    print("\u{001B}[34m🔗 Vertex AI endpoint: \(vertexConfig.baseURL.absoluteString)\u{001B}[0m")
    
    // Example 4: Azure configuration
    print("\n4. Azure OpenAI configuration:")
    let azureConfig = APIConfiguration.azure(
        apiKey: "azure-key",
        endpoint: "https://my-resource.openai.azure.com"
    )
    let _ = AnthropicClient(apiKey: "azure-key", configuration: azureConfig)
    print("\u{001B}[34m🔗 Azure endpoint: \(azureConfig.baseURL.absoluteString)\u{001B}[0m")
    
    // Example 5: Agent with custom URL
    print("\n5. Agent with custom URL:")
    let _ = Agent(
        apiKey: "test-key",
        baseURL: URL(string: "https://api.custom-claude.com")!,
        systemPrompt: "You are a helpful assistant on a custom endpoint."
    )
    print("\u{001B}[34m🔗 Agent configured with custom endpoint\u{001B}[0m")
    
    // Example 6: From .env file with custom URL
    print("\n6. Environment configuration with custom URL:")
    print("\u{001B}[33m💡 In your .env file, add:\u{001B}[0m")
    print("\u{001B}[90m   ANTHROPIC_API_KEY=your-api-key\u{001B}[0m")
    print("\u{001B}[90m   ANTHROPIC_BASE_URL=https://api.custom-claude.com\u{001B}[0m")
    print("\u{001B}[34m🔗 Then use: AnthropicClient.fromEnvironment() or Agent.fromEnvironment()\u{001B}[0m")
}

// MARK: - Error Handling Example

func errorHandlingExample() async {
    // Example with invalid configuration
    let client = AnthropicClient(apiKey: "invalid-key")
    
    print("\u{001B}[36m📝 Prompt: Test message (with invalid API key)\u{001B}[0m")
    do {
        let response = try await client.complete("Test message")
        print("\u{001B}[32m✅ Unexpected success: \(response)\u{001B}[0m")
    } catch let error as AnthropicError {
        switch error {
        case .apiError(let code, let message):
            print("\u{001B}[31m❌ API Error \(code): \(message)\u{001B}[0m")
        case .networkError(let underlying):
            print("\u{001B}[31m❌ Network Error: \(underlying.localizedDescription)\u{001B}[0m")
        case .invalidAPIKey:
            print("\u{001B}[31m❌ Invalid API key provided\u{001B}[0m")
        default:
            print("\u{001B}[31m❌ Other Anthropic error: \(error.description)\u{001B}[0m")
        }
    } catch {
        print("\u{001B}[31m❌ Unexpected error: \(error)\u{001B}[0m")
    }
}

// MARK: - Main Example Runner

@main
struct Examples {
    static func main() async {
        print("Anthropic4Swift Examples")
        print("========================")
        
        // Color Legend
        print("\n\u{001B}[90mColor Legend:\u{001B}[0m")
        print("\u{001B}[36m📝 Cyan = User Prompts\u{001B}[0m")
        print("\u{001B}[33m🎭 Yellow = System Prompts\u{001B}[0m")
        print("\u{001B}[32m🤖 Green = AI Responses\u{001B}[0m")
        print("\u{001B}[35m🔧 Magenta = Tool Calls\u{001B}[0m")
        print("\u{001B}[34m📊 Blue = Metrics/Info\u{001B}[0m")
        print("\u{001B}[31m❌ Red = Errors\u{001B}[0m")
        print("\u{001B}[95m📸 Light Magenta = Test Headers\u{001B}[0m")
        
        // Note: Create a .env file with ANTHROPIC_API_KEY=your-actual-key to run these examples
        
        // 1. Simple Client Usage
        print("\n1. Simple Client Usage:")
        print("-----------------------")
        do {
            try await simpleClientExample()
        } catch {
            print("\u{001B}[31m❌ Example 1 failed: \(error)\u{001B}[0m")
        }
        
        // 2. Agent Usage
        print("\n2. Agent Usage:")
        print("---------------")
        do {
            try await agentExample()
        } catch {
            print("\u{001B}[31m❌ Example 2 failed: \(error)\u{001B}[0m")
        }
        
        // 3. Tool Usage
        print("\n3. Tool Usage:")
        print("--------------")
        do {
            try await toolExample()
        } catch {
            print("\u{001B}[31m❌ Example 3 failed: \(error)\u{001B}[0m")
        }
        
        // 4. Message Builder
        print("\n4. Message Builder Usage:")
        print("-------------------------")
        do {
            try await messageBuilderExample()
        } catch {
            print("\u{001B}[31m❌ Example 4 failed: \(error)\u{001B}[0m")
        }
        
        // 5. Streaming
        if #available(macOS 10.15, *) {
            print("\n5. Streaming Usage:")
            print("-------------------")
            do {
                try await streamingExample()
            } catch {
                print("\u{001B}[31m❌ Example 5 (Streaming) failed: \(error)\u{001B}[0m")
            }
        }
        
        // 6. Observability
        print("\n6. Observability Usage:")
        print("-----------------------")
        do {
            try await observabilityExample()
        } catch {
            print("\u{001B}[31m❌ Example 6 failed: \(error)\u{001B}[0m")
        }
        
        // 7. Image Testing with TestData
        print("\n7. Image Testing:")
        print("-----------------")
        do {
            try await imageTestingExample()
        } catch {
            print("\u{001B}[31m❌ Example 7 failed: \(error)\u{001B}[0m")
        }
        
        // 8. Custom URLs/Endpoints
        print("\n8. Custom URLs/Endpoints:")
        print("--------------------------")
        do {
            try await customURLExample()
        } catch {
            print("\u{001B}[31m❌ Example 8 failed: \(error)\u{001B}[0m")
        }
        
        // 9. Error Handling (doesn't throw)
        print("\n9. Error Handling Example:")
        print("--------------------------")
        await errorHandlingExample()
        
        print("\nAll examples completed!")
    }
}
