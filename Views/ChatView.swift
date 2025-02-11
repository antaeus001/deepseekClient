import SwiftUI

struct ChatView: View {
    let chat: Chat
    @StateObject private var viewModel: ChatViewModel
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isScrolled = false
    @State private var showScrollToBottom = false
    @FocusState private var isInputFocused: Bool
    @State private var lastMessageId: String?
    
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
                    scrollToBottom(animated: false)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    scrollToBottom()
                }
                // 监听最后一条消息的内容变化
                .onChange(of: viewModel.messages.last?.content) { _ in
                    scrollToBottom()
                }
                // 监听滚动位置
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        isScrolled = true
                    }
                )
                .overlay(
                    // 滚动到底部按钮
                    ScrollToBottomButton(isVisible: isScrolled) {
                        withAnimation {
                            scrollToBottom()
                            isScrolled = false
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
                    isScrolled = false
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
    
    private func scrollToBottom(animated: Bool = true) {
        guard let lastMessage = viewModel.messages.last else { return }
        
        // 如果消息 ID 变化或内容变化，都需要滚动
        if lastMessageId != lastMessage.id || !isScrolled {
            if animated {
                withAnimation {
                    scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                }
            } else {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
            lastMessageId = lastMessage.id
        }
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