import Foundation

@resultBuilder
public struct MessageBuilder {
    public static func buildBlock(_ components: [ContentBlock]...) -> [ContentBlock] {
        components.flatMap { $0 }
    }
    
    public static func buildArray(_ components: [[ContentBlock]]) -> [ContentBlock] {
        components.flatMap { $0 }
    }
    
    public static func buildOptional(_ component: [ContentBlock]?) -> [ContentBlock] {
        component ?? []
    }
    
    public static func buildEither(first component: [ContentBlock]) -> [ContentBlock] {
        component
    }
    
    public static func buildEither(second component: [ContentBlock]) -> [ContentBlock] {
        component
    }
}

public struct UserMessage {
    public let blocks: [ContentBlock]
    
    public init(@MessageBuilder content: () -> [ContentBlock]) {
        self.blocks = content()
    }
    
    public init(_ text: String) {
        self.blocks = [.text(text)]
    }
    
    public var message: Message {
        Message.user(blocks)
    }
}

public struct Text {
    public let text: String
    
    public init(_ text: String) {
        self.text = text
    }
}

extension Text: ContentBlockConvertible {
    public func toContentBlock() -> ContentBlock {
        .text(text)
    }
}

public protocol ContentBlockConvertible {
    func toContentBlock() -> ContentBlock
}

extension ContentBlock: ContentBlockConvertible {
    public func toContentBlock() -> ContentBlock {
        self
    }
}

extension MessageBuilder {
    public static func buildExpression(_ expression: ContentBlockConvertible) -> [ContentBlock] {
        [expression.toContentBlock()]
    }
    
    public static func buildExpression(_ expression: String) -> [ContentBlock] {
        [.text(expression)]
    }
    
    public static func buildExpression(_ expression: Text) -> [ContentBlock] {
        [expression.toContentBlock()]
    }
}