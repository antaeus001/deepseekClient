import Foundation

struct Message: Identifiable, Codable {
    let id: String
    let content: String
    let reasoningContent: String?
    let role: MessageRole
    let timestamp: Date
    var status: MessageStatus = .success
    
    enum MessageRole: String, Codable {
        case user
        case assistant
    }
    
    struct MessageStatus: RawRepresentable, Codable, Equatable {
        let rawValue: String
        
        init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        static let sending = MessageStatus(rawValue: "sending")
        static let success = MessageStatus(rawValue: "success")
        static let failed = MessageStatus(rawValue: "failed")
        static let streaming = MessageStatus(rawValue: "streaming")
    }
    
    init(id: String, content: String, reasoningContent: String?, role: MessageRole, timestamp: Date, status: MessageStatus = .success) {
        self.id = id
        self.content = content
        self.reasoningContent = reasoningContent
        self.role = role
        self.timestamp = timestamp
        self.status = status
    }
} 