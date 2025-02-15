import Foundation
import SwiftUI

// 确保 Message 模型可见
typealias MessageRole = Message.MessageRole
typealias MessageStatus = Message.MessageStatus

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var chatTitle: String = "新会话"
    @Published private(set) var chat: Chat?
    @Published var isDeepThinking = false
    
    private let deepSeekService = DeepSeekService.shared
    private let databaseService = DatabaseService.shared
    
    init(chat: Chat? = nil) {
        self.chat = chat
        if let chat = chat {
            self.messages = chat.messages
            self.chatTitle = chat.title
        }
    }
    
    func toggleDeepThinking(_ isEnabled: Bool) {
        withAnimation(.spring(duration: 0.3)) {  // 添加动画
            isDeepThinking = isEnabled
            deepSeekService.setModel(isEnabled ? "deepseek-reasoner" : "deepseek-chat")
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
            reasoningContent: nil,
            role: .user,
            timestamp: Date(),
            status: .sending
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
            let responseMessage = Message(
                id: UUID().uuidString,
                content: "",
                reasoningContent: "",
                role: .assistant,
                timestamp: Date(),
                status: .streaming
            )
            messages.append(responseMessage)
            
            var accumulatedContent = ""
            var accumulatedReasoning = ""
            let stream = try await deepSeekService.sendMessage(content, chatId: currentChat.id)
            
            print("🔄 开始接收流式响应...")
            
            for try await (text, reasoning) in stream {
                // 打印每次接收到的内容
                if !text.isEmpty {
                    print("📝 收到内容: \(text)")
                    accumulatedContent += text
                }
                
                if let reasoning = reasoning {
                    print("🤔 收到推理: \(reasoning)")
                    // 直接使用新的推理内容
                    accumulatedReasoning = reasoning
                }
                
                // 打印当前累积的内容
                print("📄 当前内容: \(accumulatedContent)")
                print("💭 当前推理: \(accumulatedReasoning)")
                
                if let index = messages.lastIndex(where: { $0.id == responseMessage.id }) {
                    // 使用 Task 来避免过于频繁的 UI 更新
                    await Task { @MainActor in
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
                
                // 添加小延迟以避免过于频繁的更新
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            print("✅ 流式响应接收完成")
            print("📝 最终内容: \(accumulatedContent)")
            print("🤔 最终推理: \(accumulatedReasoning)")
            
            // 流式输出完成后，保存最终消息
            let finalResponseMessage = Message(
                id: responseMessage.id,
                content: accumulatedContent,
                reasoningContent: accumulatedReasoning.isEmpty ? nil : accumulatedReasoning,
                role: .assistant,
                timestamp: responseMessage.timestamp,
                status: .success
            )
            
            // 保存 AI 响应到数据库
            try databaseService.saveMessage(value: finalResponseMessage, chatId: currentChat.id)
            
            // 更新消息列表中的最后一条消息
            if let index = messages.lastIndex(where: { $0.id == responseMessage.id }) {
                messages[index] = finalResponseMessage
            }
            
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
            print("❌ 流式响应出错: \(error)")
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
}

