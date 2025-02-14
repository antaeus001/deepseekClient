import SwiftUI

struct ChatView: View {
    let chat: Chat?  // 可选，因为新会话时为 nil
    let isNewChat: Bool
    let onChatCreated: ((Chat?) -> Void)?  // 回调
    @StateObject private var viewModel: ChatViewModel
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    
    // 用于缓存视图的状态
    @State private var visibleMessageIds = Set<String>()
    
    init(chat: Chat? = nil, isNewChat: Bool = false, onChatCreated: ((Chat?) -> Void)? = nil) {
        self.chat = chat
        self.isNewChat = isNewChat
        self.onChatCreated = onChatCreated
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
                                // 使用 onAppear 和 onDisappear 跟踪可见消息
                                .onAppear {
                                    visibleMessageIds.insert(message.id)
                                }
                                .onDisappear {
                                    visibleMessageIds.remove(message.id)
                                }
                        }
                    }
                    .padding(.vertical, 20)
                }
                .background(Color(.systemGroupedBackground))
                // 使用 ScrollView 的性能优化选项
                .scrollDismissesKeyboard(.immediately)
                .scrollIndicators(.hidden)
                .animation(.none, value: viewModel.messages.count)
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom(animated: false)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    scrollToBottom()
                }
                .onChange(of: viewModel.messages.last?.content) { _ in
                    // 只有当最后一条消息可见时才自动滚动
                    if let lastMessage = viewModel.messages.last,
                       visibleMessageIds.contains(lastMessage.id) {
                        scrollToBottom()
                    }
                }
            }
            
            // 输入区域
            MessageInputView(text: $inputText) {
                Task {
                    if isNewChat {
                        await viewModel.createAndSendFirstMessage(inputText)
                        onChatCreated?(viewModel.chat)
                    } else {
                        await viewModel.sendMessage(inputText)
                    }
                    inputText = ""
                    isInputFocused = false
                }
            }
            .focused($isInputFocused)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.chatTitle)
                    .font(.headline)
            }
        }
    }
    
    private func scrollToBottom(animated: Bool = true) {
        guard let lastMessage = viewModel.messages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.3)) {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
} 