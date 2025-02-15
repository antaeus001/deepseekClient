import Foundation
import SwiftUI

// 确保 Message 模型可见
typealias MessageRole = Message.MessageRole
typealias MessageStatus = Message.MessageStatus

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var chatTitle: String = "新会话"
    @Published private(set) var chat: Chat?
    @Published var isDeepThinking = false  // 默认为 false
    @Published var showSettings = false
    
    private let deepSeekService = DeepSeekService.shared
    private let databaseService = DatabaseService.shared
    
    init(chat: Chat? = nil) {
        self.chat = chat
        if let chat = chat {
            self.messages = chat.messages
            self.chatTitle = chat.title
        }
        // 确保初始化时使用会话模型
        deepSeekService.setModel(false)
    }
    
    func toggleDeepThinking(_ isEnabled: Bool) {
        withAnimation(.spring(duration: 0.3)) {
            isDeepThinking = isEnabled
            deepSeekService.setModel(isEnabled)
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
        let timestamp = Date()
        let newMessage = Message(
            id: UUID().uuidString,
            content: content,
            reasoningContent: nil,
            role: .user,
            timestamp: timestamp,
            status: .sending
        )
        
        messages.append(newMessage)
        
        do {
            try databaseService.saveMessage(value: newMessage, chatId: currentChat.id)
            
            if let index = messages.firstIndex(where: { $0.id == newMessage.id }) {
                messages[index].status = .success
            }
            
            // 更新会话时间
            let updatedChat = Chat(
                id: currentChat.id,
                title: chatTitle,
                createdAt: currentChat.createdAt,
                updatedAt: timestamp,
                messages: messages
            )
            try databaseService.saveChat(updatedChat)
            self.chat = updatedChat
            
            // 创建 AI 响应消息
            let responseMessage = Message(
                id: UUID().uuidString,
                content: "",
                reasoningContent: nil,
                role: .assistant,
                timestamp: timestamp,
                status: .streaming
            )
            messages.append(responseMessage)
            
            var accumulatedContent = ""
            var accumulatedReasoning = ""
            let stream = try await deepSeekService.sendMessage(content, chatId: currentChat.id)
            
            for try await (text, reasoning) in stream {
                if let index = messages.lastIndex(where: { $0.id == responseMessage.id }) {
                    // 使用 Task 来避免过于频繁的 UI 更新
                    await Task { @MainActor in
                        if !text.isEmpty {
                            accumulatedContent += text
                        }
                        if let reasoning = reasoning {
                            accumulatedReasoning = reasoning
                        }
                        
                        messages[index] = Message(
                            id: responseMessage.id,
                            content: accumulatedContent,
                            reasoningContent: accumulatedReasoning.isEmpty ? nil : accumulatedReasoning,
                            role: .assistant,
                            timestamp: responseMessage.timestamp,
                            status: .streaming
                        )
                    }.value
                }
            }
            
            // 在保存最终消息时也更新时间戳
            let finalTimestamp = Date()
            let finalResponseMessage = Message(
                id: responseMessage.id,
                content: accumulatedContent,
                reasoningContent: accumulatedReasoning.isEmpty ? nil : accumulatedReasoning,
                role: .assistant,
                timestamp: finalTimestamp,
                status: .success
            )
            
            try databaseService.saveMessage(value: finalResponseMessage, chatId: currentChat.id)
            
            if let index = messages.lastIndex(where: { $0.id == responseMessage.id }) {
                messages[index] = finalResponseMessage
            }
            
            // 最后更新会话时间
            let finalChat = Chat(
                id: currentChat.id,
                title: chatTitle,
                createdAt: currentChat.createdAt,
                updatedAt: finalTimestamp,
                messages: messages
            )
            try databaseService.saveChat(finalChat)
            self.chat = finalChat
            
        } catch {
            if let index = messages.lastIndex(where: { $0.role == .assistant }) {
                messages[index].status = .failed
            }
        }
    }
    
    var hasAIResponse: Bool {
        messages.contains { message in 
            message.role == .assistant && message.status == .success
        }
    }
    
    var isConfigValid: Bool {
        let settings = deepSeekService.settings
        return !settings.apiEndpoint.isEmpty && 
               !settings.apiKey.isEmpty && 
               !settings.chatModel.isEmpty && 
               !settings.reasonerModel.isEmpty
    }
}

