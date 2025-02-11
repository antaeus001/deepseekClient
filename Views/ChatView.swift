import SwiftUI

struct ChatView: View {
    let chat: Chat
    @StateObject private var viewModel: ChatViewModel
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isScrolled = false
    @State private var showScrollToBottom = false
    @FocusState private var isInputFocused: Bool
    
    init(chat: Chat) {
        self.chat = chat
        _viewModel = StateObject(wrappedValue: ChatViewModel(chat: chat))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 聊天记录
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                                .transition(.opacity)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .background(Color(.systemGroupedBackground))
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    withAnimation {
                        scrollToBottom()
                    }
                }
                .overlay(
                    // 滚动到底部按钮
                    ScrollToBottomButton(isVisible: showScrollToBottom) {
                        withAnimation {
                            scrollToBottom()
                        }
                    }
                    .padding(.bottom),
                    alignment: .bottom
                )
            }
            
            // 输入区域
            MessageInputView(text: $inputText) {
                Task {
                    await viewModel.sendMessage(inputText)
                    inputText = ""
                    isInputFocused = false
                }
            }
            .focused($isInputFocused)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(chat.title)
                    .font(.headline)
            }
        }
    }
    
    private func scrollToBottom() {
        guard let lastMessage = viewModel.messages.last else { return }
        scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
    }
}

// 滚动到底部按钮
struct ScrollToBottomButton: View {
    let isVisible: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .padding(8)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 3)
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut, value: isVisible)
    }
} 