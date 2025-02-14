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
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    
    var body: some View {
        Group {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone 使用 NavigationStack
                NavigationStack {
                    ChatListView(selectedChat: $selectedChat)
                        .navigationTitle("会话")
                        .navigationDestination(item: $selectedChat) { chat in
                            ChatView(chat: chat)
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    showSettings = true
                                } label: {
                                    Image(systemName: "gear")
                                }
                            }
                        }
                }
                .sheet(isPresented: $showSettings) {
                    NavigationView {
                        SettingsView()
                            .navigationTitle("设置")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("完成") {
                                        showSettings = false
                                    }
                                }
                            }
                    }
                }
            } else {
                // iPad 使用 NavigationSplitView
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    ChatListView(selectedChat: $selectedChat)
                        .navigationTitle("会话")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    showSettings = true
                                } label: {
                                    Image(systemName: "gear")
                                }
                            }
                        }
                } detail: {
                    ChatView(
                        chat: selectedChat,
                        isNewChat: selectedChat == nil,
                        onChatCreated: { newChat in
                            selectedChat = newChat
                        }
                    )
                }
                .sheet(isPresented: $showSettings) {
                    NavigationView {
                        SettingsView()
                            .navigationTitle("设置")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("完成") {
                                        showSettings = false
                                    }
                                }
                            }
                    }
                }
            }
            #else
            // macOS 使用 NavigationSplitView
            NavigationSplitView(columnVisibility: $columnVisibility) {
                ChatListView(selectedChat: $selectedChat)
                    .navigationTitle("会话")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gear")
                            }
                        }
                    }
            } detail: {
                ChatView(
                    chat: selectedChat,
                    isNewChat: selectedChat == nil,
                    onChatCreated: { newChat in
                        selectedChat = newChat
                    }
                )
            }
            .sheet(isPresented: $showSettings) {
                NavigationView {
                    SettingsView()
                        .navigationTitle("设置")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("完成") {
                                    showSettings = false
                                }
                            }
                        }
                }
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
}

// 添加通知名称扩展
extension Notification.Name {
    static let refreshChatList = Notification.Name("refreshChatList")
}
