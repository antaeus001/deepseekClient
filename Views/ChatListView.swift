import SwiftUI

struct ChatListView: View {
    @Binding var selectedChat: Chat?
    @Environment(\.dismiss) private var dismiss
    @State private var chats: [Chat] = []
    @State private var showDeleteAlert = false
    @State private var chatToDelete: Chat?
    @State private var isLoading = true
    
    private let databaseService = DatabaseService.shared
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else {
                // 只在有历史会话时显示"开始新对话"按钮
                if !chats.isEmpty {
                    // 新建会话按钮
                    Button {
                        selectedChat = nil
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("开始新对话")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(.systemGroupedBackground))
                    
                    Section {
                        ForEach(chats) { chat in
                            ChatRow(chat: chat)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // 先设置 selectedChat 为 nil 触发重置
                                    selectedChat = nil
                                    // 然后设置新的选中会话
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        selectedChat = chat
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        chatToDelete = chat
                                        showDeleteAlert = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        renameChat(chat)
                                    } label: {
                                        Label("重命名", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                        }
                    } header: {
                        Text("历史会话")
                            .textCase(nil)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadChats()
        }
        .overlay {
            if !isLoading && chats.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("开始您的第一个对话")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Button {
                        // 先清除选中的会话
                        selectedChat = nil
                        // 返回首页
                        dismiss()
                    } label: {
                        Label("新建会话", systemImage: "plus")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert, presenting: chatToDelete) { chat in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteChat(chat)
            }
        } message: { chat in
            Text("确定要删除「\(chat.title)」吗？此操作不可恢复。")
        }
        .onAppear {
            Task {
                await loadChats()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshChatList)) { _ in
            Task {
                await loadChats()
            }
        }
    }
    
    private func loadChats() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            chats = try await databaseService.fetchChats()
            chats.sort { $0.updatedAt > $1.updatedAt }
            
            if let selectedId = selectedChat?.id,
               let updatedChat = chats.first(where: { $0.id == selectedId }) {
                selectedChat = updatedChat
            }
        } catch {
            print("Error loading chats: \(error)")
        }
    }
    
    private func deleteChat(_ chat: Chat) {
        do {
            try databaseService.deleteChat(chat)
            if selectedChat?.id == chat.id {
                selectedChat = nil
            }
            chats.removeAll { $0.id == chat.id }
        } catch {
            print("Error deleting chat: \(error)")
        }
    }
    
    private func renameChat(_ chat: Chat) {
        // TODO: 实现重命名功能
    }
}

// 优化会话行视图
struct ChatRow: View {
    let chat: Chat
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let lastMessage = chat.messages.last {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Text(chat.updatedAt.timeAgoDisplay())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
} 