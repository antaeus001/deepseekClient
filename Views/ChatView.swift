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
    @State private var showSettingsSheet = false  // 添加这一行
    
    init(chat: Chat? = nil, isNewChat: Bool = false, onChatCreated: ((Chat?) -> Void)? = nil) {
        self.chat = chat
        self.isNewChat = isNewChat
        self.onChatCreated = onChatCreated
        _viewModel = StateObject(wrappedValue: ChatViewModel(chat: chat))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "message")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                                .padding(.top, 60)
                            
                            Text("开始新的对话")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("你可以：")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    Image(systemName: "brain")
                                    Text("开启深度思考模式获得更详细的推理过程")
                                }
                                .foregroundColor(.gray)
                                
                                HStack {
                                    Image(systemName: "gear")
                                    Text("在设置中配置 API 信息")
                                }
                                .foregroundColor(.gray)
                                
                                HStack {
                                    Image(systemName: "questionmark.circle")
                                    Text("输入任何问题开始对话")
                                }
                                .foregroundColor(.gray)
                            }
                            .font(.footnote)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
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
                    scrollToBottom()
                }
                .onChange(of: viewModel.messages.last?.reasoningContent) { _ in
                    // 当推理内容更新时也滚动到底部
                    scrollToBottom()
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
                    .opacity(0.5),
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
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsView()
            }
        }
    }
    
    private func scrollToBottom(animated: Bool = true) {
        guard let lastMessage = viewModel.messages.last else { return }
        
        // 如果最后一条消息是 AI 回复且正在流式输出，总是滚动
        if lastMessage.role == .assistant && lastMessage.status == .streaming {
            if animated {
                withAnimation(.easeOut(duration: 0.3)) {
                    scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                }
            } else {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
        // 否则只在最后一条消息可见时滚动
        else if visibleMessageIds.contains(lastMessage.id) {
            if animated {
                withAnimation(.easeOut(duration: 0.3)) {
                    scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                }
            } else {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // 检查配置
        if !viewModel.isConfigValid {
            showSettingsSheet = true
            return
        }
        
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