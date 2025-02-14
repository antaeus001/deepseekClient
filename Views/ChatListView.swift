import SwiftUI

struct ChatListView: View {
    @Binding var selectedChat: Chat?
    @State private var chats: [Chat] = []
    @State private var showDeleteAlert = false
    @State private var chatToDelete: Chat?
    @State private var isLoading = true
    @State private var showNewChat = false
    
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
                // 新建会话按钮
                Button {
                    showNewChat = true
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
                
                if !chats.isEmpty {
                    Section {
                        ForEach(chats) { chat in
                            ChatRow(chat: chat)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedChat = chat
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
                        showNewChat = true
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
        .navigationDestination(isPresented: $showNewChat) {
            ChatView(isNewChat: true) { newChat in
                if let chat = newChat {
                    selectedChat = chat
                    Task {
                        await loadChats()
                    }
                }
                showNewChat = false
            }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // 图标
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "bubble.left.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    )
                
                // 主要内容
                VStack(alignment: .leading, spacing: 4) {
                    // 标题和时间
                    HStack {
                        Text(chat.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(timeString(from: chat.updatedAt))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    // 最后一条消息预览
                    if let lastMessage = chat.messages.last {
                        HStack {
                            if lastMessage.role == .assistant {
                                Text("AI: ")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 14))
                            }
                            Text(lastMessage.content)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeString(from date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: date)
        }
    }
}

// 添加时间显示扩展
extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self, to: now)
        
        if let year = components.year, year > 0 {
            return "\(year)年前"
        } else if let month = components.month, month > 0 {
            return "\(month)月前"
        } else if let day = components.day, day > 0 {
            return "\(day)天前"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)小时前"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)分钟前"
        } else {
            return "刚刚"
        }
    }
} 