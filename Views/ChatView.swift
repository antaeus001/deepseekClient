import SwiftUI

struct ChatView: View {
    let chat: Chat?  // 可选，因为新会话时为 nil
    let isNewChat: Bool
    let onChatCreated: ((Chat?) -> Void)?  // 回调
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""  // 保持为本地状态
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
            VStack(spacing: 8) {
                // 功能按钮区
                HStack(spacing: 16) {
                    Button {
                        viewModel.toggleDeepThinking(!viewModel.isDeepThinking)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "brain")
                                .symbolEffect(.bounce, value: viewModel.isDeepThinking)
                            Text("深度思考")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(viewModel.isDeepThinking ? .white : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(viewModel.isDeepThinking ? Color.blue : Color.blue.opacity(0.1))
                        )
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 输入框和发送按钮
                HStack(spacing: 12) {
                    TextField("输入消息...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(!inputText.isEmpty ? .blue : .gray)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separator))
                    .opacity(0.8),
                alignment: .top
            )
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
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        Task {
            if isNewChat {
                await viewModel.createAndSendFirstMessage(text)
                onChatCreated?(viewModel.chat)
            } else {
                await viewModel.sendMessage(text)
            }
            inputText = ""
            isInputFocused = false
        }
    }
}

// 添加 pressEvents 修饰符
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
} 