import SwiftUI

class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = true
    
    private let databaseService = DatabaseService.shared
    
    func loadChats() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            chats = try await databaseService.fetchChats()
            chats.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Error loading chats: \(error)")
        }
    }
    
    func deleteChat(_ chat: Chat) throws {
        try databaseService.deleteChat(chat)
        chats.removeAll { $0.id == chat.id }
    }
    
    func renameChat(_ chat: Chat, newTitle: String) throws {
        // TODO: 实现重命名功能
    }
} 