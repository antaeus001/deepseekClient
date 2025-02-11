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
            // 创建 AI 响应消息
            let responseMessage = Message(
                id: UUID().uuidString,
                content: "",
                role: .assistant,
                timestamp: Date()
            )
            messages.append(responseMessage)
            
            var accumulatedContent = ""
            let stream = try await deepSeekService.sendMessage(content, chatId: chat.id)
            
            for try await text in stream {
                accumulatedContent += text
                // 更新最后一条消息的内容
                if let index = messages.lastIndex(where: { $0.id == responseMessage.id }) {
                    messages[index] = Message(
                        id: responseMessage.id,
                        content: accumulatedContent,
                        role: .assistant,
                        timestamp: responseMessage.timestamp
                    )
                }
            }
            
            // 保存到数据库
            try databaseService.saveMessage(value: newMessage, chatId: chat.id)
            try databaseService.saveMessage(value: messages.last!, chatId: chat.id)
            
        } catch {
            print("Error sending message: \(error)")
            if let index = messages.firstIndex(where: { $0.id == newMessage.id }) {
                messages[index].status = .failed
            }
        }
    }
} 