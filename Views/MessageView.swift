import SwiftUI
import MarkdownUI

struct MessageView: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                // AI 头像
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                    )
            } else {
                Spacer(minLength: 32)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                if message.role == .assistant {
                    Group {
                        if let reasoning = message.reasoningContent,
                           !reasoning.isEmpty {
                            // 推理内容
                            VStack(alignment: .leading, spacing: 4) {
                                Text("推理过程：")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                if message.status == .streaming {
                                    TypewriterText(text: reasoning)
                                        .foregroundColor(.gray)
                                        .transaction { transaction in
                                            transaction.animation = .none  // 禁用隐式动画
                                        }
                                } else {
                                    MessageContentView(content: reasoning)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                    .transaction { transaction in
                        // 只对显示/隐藏使用动画
                        if transaction.animation != nil {
                            transaction.animation = .easeInOut(duration: 0.2)
                        }
                    }
                }
                
                // 主要内容
                if message.status == .streaming {
                    TypewriterText(text: message.content)
                        .transaction { transaction in
                            transaction.animation = .none  // 禁用隐式动画
                        }
                } else {
                    MessageContentView(content: message.content)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(message.role == .assistant ? 
                          Color(.systemBackground) : 
                          Color.blue.opacity(0.8))
            )
            
            if message.role == .user {
                // 用户头像
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                    )
            } else {
                Spacer(minLength: 32)
            }
        }
        .padding(.horizontal)
    }
}

// Markdown 渲染视图
struct MessageContentView: View {
    let content: String
    
    var body: some View {
        Markdown(content)
            .textSelection(.enabled)
            .markdownTheme(
                .gitHub.text {
                    FontFamily(.system())
                    FontSize(15)
                    ForegroundColor(.primary)
                }
                .code {
                    FontFamily(.system(.monospaced))
                    FontSize(14)
                    BackgroundColor(.secondary.opacity(0.1))
                }
                .link {
                    ForegroundColor(.blue)
                }
            )
            .padding(.vertical, 2)
    }
}

// 打字机效果视图
struct TypewriterText: View {
    let text: String
    
    var body: some View {
        Markdown(text)
            .textSelection(.enabled)
            .markdownTheme(
                .gitHub.text {
                    FontFamily(.system())
                    FontSize(15)
                    ForegroundColor(.primary)
                }
                .code {
                    FontFamily(.system(.monospaced))
                    FontSize(14)
                    BackgroundColor(.secondary.opacity(0.1))
                }
                .link {
                    ForegroundColor(.blue)
                }
            )
            .transaction { transaction in
                // 只在文本变化时使用短暂的动画
                if transaction.animation != nil {
                    transaction.animation = .easeOut(duration: 0.1)
                }
            }
    }
}