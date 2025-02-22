import SwiftUI

struct ChatView: View {
    let chat: Chat?  // 可选，因为新会话时为 nil
    let isNewChat: Bool
    let resetTrigger: Bool  // 添加重置触发器
    let onChatCreated: ((Chat?) -> Void)?  // 回调
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""  // 保持为本地状态
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    
    // 用于缓存视图的状态
    @State private var visibleMessageIds = Set<String>()
    @State private var showSettingsSheet = false  // 添加这一行
    @State private var userScrolling = false  // 添加用户滚动状态
    @State private var scrollViewContentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    
    init(chat: Chat? = nil, isNewChat: Bool = false, resetTrigger: Bool = false, onChatCreated: ((Chat?) -> Void)? = nil) {
        self.chat = chat
        self.isNewChat = isNewChat
        self.resetTrigger = resetTrigger
        self.onChatCreated = onChatCreated
        
        let viewModel = ChatViewModel()
        if let chat = chat {
            print("初始化时加载会话: \(chat.title)")  // 添加日志
            viewModel.loadChat(chat)
        }
        _viewModel = StateObject(wrappedValue: viewModel)
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
                                
                                // 添加开源信息
                                HStack {
                                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    Text("代码已开源于 GitHub")
                                }
                                .foregroundColor(.gray)
                                
                                // 添加可点击的链接
                                Link(destination: URL(string: "https://github.com/antaeus001/deepseekClient")!) {
                                    HStack {
                                        Text("AI Client")
                                            .underline()
                                        Image(systemName: "arrow.up.right")
                                    }
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                                }
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
                        GeometryReader { geometry in
                            let frame = geometry.frame(in: .named("scroll"))
                            let minY = frame.minY
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: minY
                            )
                            .onChange(of: minY) { newValue in
                                scrollOffset = abs(newValue)
                                let maxScroll = max(0, scrollViewContentHeight - scrollViewHeight)
                                let distanceToBottom = max(0, maxScroll - scrollOffset)
                                
                                if distanceToBottom <= 20 {
                                    userScrolling = false
                                }
                            }
                        }
                        .frame(height: 0)
                        
                        LazyVStack(spacing: 20) {
                            ForEach(viewModel.messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                                    .transition(.opacity)
                                    .onAppear {
                                        visibleMessageIds.insert(message.id)
                                    }
                                    .onDisappear {
                                        visibleMessageIds.remove(message.id)
                                    }
                            }
                        }
                        .padding(.vertical, 20)
                        .overlay(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(key: ContentHeightPreferenceKey.self, value: geometry.size.height)
                            }
                        )
                    }
                }
                .background(Color(.systemGroupedBackground))
                // 使用 ScrollView 的性能优化选项
                .scrollDismissesKeyboard(.immediately)
                .scrollIndicators(.hidden)
                .animation(.none, value: viewModel.messages.count)
                // 添加手势识别器
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.height
                            let maxScroll = max(0, scrollViewContentHeight - scrollViewHeight)
                            let distanceToBottom = max(0, maxScroll - scrollOffset)
                            
                            if translation > 0 {
                                // 向下滚动，远离底部
                                userScrolling = true
                            } else if translation <= 0 && distanceToBottom <= 20 {
                                // 向上滚动且接近底部
                                userScrolling = false
                            }
                        }
                )
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom(animated: false)
                    if let chat = chat {
                        print("视图出现时加载会话: \(chat.title)")  // 添加日志
                        viewModel.loadChat(chat)
                    }
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
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                scrollViewContentHeight = height
            }
            .background(
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        scrollViewHeight = geometry.size.height
                    }
                    .onChange(of: geometry.size.height) { newHeight in
                        scrollViewHeight = newHeight
                    }
                }
            )
            
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
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") {
                                showSettingsSheet = false
                            }
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onChange(of: isNewChat) { newValue in
            if newValue {
                // 如果切换到新会话模式，重置 ViewModel
                viewModel.reset()
                inputText = ""
            }
        }
        .onChange(of: chat) { newChat in
            if let newChat = newChat {
                print("会话变化时加载: \(newChat.title)")  // 添加日志
                viewModel.loadChat(newChat)
            }
        }
        .onChange(of: resetTrigger) { _ in
            viewModel.reset()
            inputText = ""
            isInputFocused = false
            visibleMessageIds.removeAll()
        }
    }
    
    private func scrollToBottom(animated: Bool = true) {
        guard let lastMessage = viewModel.messages.last else { return }
        
        // 如果用户正在手动滚动，则不自动滚动
        guard !userScrolling else { return }
        
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
            // 只有在真正的新会话时才创建新会话
            if isNewChat && viewModel.messages.isEmpty {
                await viewModel.createAndSendFirstMessage(text)
                onChatCreated?(viewModel.chat)
            } else {
                // 否则继续在当前会话中发送消息
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

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
} 