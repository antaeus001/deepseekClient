import SwiftUI

struct ChatListView: View {
    @Binding var selectedChat: Chat?
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var chatToDelete: Chat?
    @StateObject private var viewModel = ChatListViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    // 只在有历史会话时显示"开始新对话"按钮
                    if !viewModel.chats.isEmpty {
                        // 新建会话按钮
                        Button(action: {
                            // 1. 先设置 selectedChat 为 nil 触发重置
                            selectedChat = nil
                            
                            // 2. 发送通知以重置 ChatView
                            NotificationCenter.default.post(name: .resetChatView, object: nil)
                            
                            // 3. 关闭当前视图
                            dismiss()
                        }) {
                            Label("开始新会话", systemImage: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color(.systemGroupedBackground))
                        
                        Section {
                            ForEach(viewModel.chats) { chat in
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
                await viewModel.loadChats()
            }
            .overlay {
                if !viewModel.isLoading && viewModel.chats.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("开始您的第一个对话")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Button {
                            // 1. 先设置 selectedChat 为 nil 触发重置
                            selectedChat = nil
                            
                            // 2. 发送通知以重置 ChatView
                            NotificationCenter.default.post(name: .resetChatView, object: nil)
                            
                            // 3. 返回首页
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
                    await viewModel.loadChats()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .refreshChatList)) { _ in
                Task {
                    await viewModel.loadChats()
                }
            }
        }
    }
    
    private func deleteChat(_ chat: Chat) {
        do {
            try viewModel.deleteChat(chat)
            if selectedChat?.id == chat.id {
                selectedChat = nil
            }
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

// 添加通知名称扩展
extension Notification.Name {
    static let resetChatView = Notification.Name("resetChatView")
} 