import Foundation
import SwiftUI

// 确保 Message 模型可见
typealias MessageRole = Message.MessageRole
typealias MessageStatus = Message.MessageStatus

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var chatTitle: String = "新会话"
    @Published private(set) var chat: Chat?
    private let deepSeekService = DeepSeekService.shared
    private let databaseService = DatabaseService.shared
    
    init(chat: Chat?) {
        self.chat = chat
        if let chat = chat {
            // 确保所有历史消息的状态为 success
            self.messages = chat.messages.map { message in
                var updatedMessage = message
                if message.role == .user {
                    updatedMessage.status = .success
                }
                return updatedMessage
            }
            self.chatTitle = chat.title
        }
    }
    
    @MainActor
    func createAndSendFirstMessage(_ content: String) async {
        let timestamp = Date()
        let chatId = UUID().uuidString
        let title = String(content.prefix(20)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newChat = Chat(
            id: chatId,
            title: title,
            createdAt: timestamp,
            updatedAt: timestamp,
            messages: []
        )
        
        do {
            try databaseService.saveChat(newChat)
            self.chat = newChat
            self.chatTitle = title
            await sendMessage(content)
        } catch {
            print("Error creating chat: \(error)")
        }
    }
    
    @MainActor
    func sendMessage(_ content: String) async {
        guard let currentChat = chat else { return }
        let newMessage = Message(
            id: UUID().uuidString,
            content: content,
            role: .user,
            timestamp: Date(),
            status: .sending  // 初始状态为 sending
        )
        
        messages.append(newMessage)
        
        // 立即保存用户消息
        do {
            try databaseService.saveMessage(value: newMessage, chatId: currentChat.id)
            
            // 更新用户消息状态为成功
            if let index = messages.firstIndex(where: { $0.id == newMessage.id }) {
                messages[index].status = .success
            }
            
            // 更新会话时间
            let updatedChat = Chat(
                id: currentChat.id,
                title: chatTitle,
                createdAt: currentChat.createdAt,
                updatedAt: Date(),
                messages: messages
            )
            try databaseService.saveChat(updatedChat)
            self.chat = updatedChat
        } catch {
            print("Error saving user message: \(error)")
            if let index = messages.firstIndex(where: { $0.id == newMessage.id }) {
                messages[index].status = .failed
            }
            return
        }
        
        do {
            // 创建 AI 响应消息（使用打字机效果）
            let responseMessage = Message(
                id: UUID().uuidString,
                content: "",
                role: .assistant,
                timestamp: Date(),
                status: .streaming
            )
            messages.append(responseMessage)
            
            var accumulatedContent = ""
            let stream = try await deepSeekService.sendMessage(content, chatId: currentChat.id)
            
            for try await text in stream {
                accumulatedContent += text
                // 更新最后一条消息的内容，保持打字机效果
                if let index = messages.lastIndex(where: { $0.id == responseMessage.id }) {
                    messages[index] = Message(
                        id: responseMessage.id,
                        content: accumulatedContent,
                        role: .assistant,
                        timestamp: responseMessage.timestamp,
                        status: .streaming
                    )
                }
            }
            
            // 流式输出完成后，保存最终消息
            let finalResponseMessage = Message(
                id: responseMessage.id,
                content: accumulatedContent,
                role: .assistant,
                timestamp: responseMessage.timestamp,
                status: .success
            )
            
            // 保存 AI 响应到数据库
            try databaseService.saveMessage(value: finalResponseMessage, chatId: currentChat.id)
            
            // 更新会话
            let updatedChat = Chat(
                id: currentChat.id,
                title: chatTitle,
                createdAt: currentChat.createdAt,
                updatedAt: Date(),
                messages: messages
            )
            try databaseService.saveChat(updatedChat)
            self.chat = updatedChat
            
        } catch {
            print("Error getting AI response: \(error)")
            if let index = messages.lastIndex(where: { $0.role == .assistant }) {
                messages[index].status = .failed
            }
        }
    }
}