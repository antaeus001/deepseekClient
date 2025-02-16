//
//  deepseekClientApp.swift
//  deepseekClient
//
//  Created by antaeus on 2025/2/11.
//

import SwiftUI

@main
struct DeepSeekClientApp: App {
    @State private var selectedChat: Chat?
    @State private var showChatList = false
    @State private var showSettings = false
    @State private var isNewChat = true
    @State private var resetTrigger = false
    @State private var viewKey = UUID()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChatView(chat: selectedChat, isNewChat: isNewChat, resetTrigger: resetTrigger) { newChat in
                    if let chat = newChat {
                        selectedChat = chat
                        isNewChat = false
                    }
                }
                .id(viewKey)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showChatList = true
                        } label: {
                            Image(systemName: "text.bubble.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .sheet(isPresented: $showChatList) {
                    NavigationStack {
                        ChatListView(selectedChat: $selectedChat)
                            .navigationTitle("历史会话")
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("完成") {
                                        showChatList = false
                                    }
                                }
                            }
                            .onChange(of: selectedChat) { chat in
                                if chat == nil {
                                    isNewChat = true
                                    resetTrigger.toggle()
                                } else {
                                    isNewChat = false
                                    resetTrigger.toggle()
                                    viewKey = UUID()
                                }
                                showChatList = false
                            }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView()
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("完成") {
                                        showSettings = false
                                    }
                                }
                            }
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
            .tint(.blue)
        }
    }
}
