//
//  ContentView.swift
//  deepseekClient
//
//  Created by antaeus on 2025/2/11.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedChat: Chat?
    @State private var showSettings = false
    
    var body: some View {
        NavigationSplitView {
            // 左侧会话列表
            ChatListView(selectedChat: $selectedChat)
                .navigationTitle("DeepSeek")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gear")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: createNewChat) {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    
                    #if DEBUG
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Debug DB") {
                            do {
                                DatabaseService.shared.debugPrintDatabasePath()
                                try DatabaseService.shared.debugPrintAllData()
                                DatabaseService.shared.debugReadDatabase()
                            } catch {
                                print("Debug error: \(error)")
                            }
                        }
                    }
                    #endif
                }
        } detail: {
            // 右侧聊天界面
            if let chat = selectedChat {
                ChatView(chat: chat)
            } else {
                Text("选择或创建一个会话开始聊天")
                    .foregroundColor(.gray)
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                SettingsView()
            }
        }
    }
    
    private func createNewChat() {
        let newChat = Chat(
            id: UUID().uuidString,
            title: "新会话",
            createdAt: Date(),
            updatedAt: Date(),
            messages: []
        )
        selectedChat = newChat
        // TODO: 保存到数据库
    }
}

// 会话列表视图
struct ChatListView: View {
    @Binding var selectedChat: Chat?
    @State private var chats: [Chat] = []
    
    var body: some View {
        List(chats, selection: $selectedChat) { chat in
            NavigationLink(value: chat) {
                VStack(alignment: .leading) {
                    Text(chat.title)
                        .lineLimit(1)
                    Text(chat.messages.last?.content ?? "无消息")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        }
        .onAppear {
            // TODO: 从数据库加载会话列表
        }
    }
}

#Preview {
    ContentView()
}
