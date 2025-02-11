import Foundation

struct Message: Codable, Identifiable {
    let id: String
    let content: String
    let role: MessageRole
    let timestamp: Date
    var status: MessageStatus = .success
    
    enum MessageRole: String, Codable {
        case user
        case assistant
    }
    
    enum MessageStatus: String, Codable {
        case sending
        case success
        case failed
    }
} 