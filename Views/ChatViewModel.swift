import Foundation
import SwiftUI

// 确保 Message 模型可见
typealias MessageRole = Message.MessageRole
typealias MessageStatus = Message.MessageStatus

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    private let chat: Chat
    private let deepSeekService = DeepSeekService.shared
    private let databaseService = DatabaseService.shared
    
    init(chat: Chat) {
        self.chat = chat
        self.messages = chat.messages
    }
    
    @MainActor
    func sendMessage(_ content: String) async {
        let newMessage = Message(
            id: UUID().uuidString,
            content: content,
            role: .user,
            timestamp: Date(),
            status: .sending
        )
        
        messages.append(newMessage)
        
        do {
            var responseContent = ""
            let stream = try await deepSeekService.sendMessage(content, chatId: chat.id)
            
            for try await text in stream {
                responseContent += text
            }
            
            let responseMessage = Message(
                id: UUID().uuidString,
                content: responseContent,
                role: .assistant,
                timestamp: Date()
            )
            
            messages.append(responseMessage)
            
            // 保存到数据库
            try databaseService.saveMessage(value: newMessage, chatId: chat.id)
            try databaseService.saveMessage(value: responseMessage, chatId: chat.id)
            
        } catch {
            print("Error sending message: \(error)")
            // 更新消息状态为失败
            if let index = messages.firstIndex(where: { $0.id == newMessage.id }) {
                messages[index].status = .failed
            }
        }
    }
} 