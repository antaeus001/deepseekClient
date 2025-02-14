import SwiftUI
import MarkdownUI

struct MessageView: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 用户消息靠右，AI消息靠左
            if message.role == .assistant {
                // 头像
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.green)
                            .font(.system(size: 18))
                    )
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // 时间显示（如果需要）
                Text(formatTime(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.8))
                
                // 消息气泡
                HStack {
                    if message.role == .user { Spacer(minLength: 60) }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        if message.status == .streaming {
                            TypewriterText(text: message.content)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        } else {
                            MessageContentView(content: message.content)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        
                        // 状态指示器
                        if message.status == .sending {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.5)
                                Text("发送中...")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .padding(.leading, 12)
                            .padding(.bottom, 6)
                        } else if message.status == .failed {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("发送失败")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                            }
                            .padding(.leading, 12)
                            .padding(.bottom, 6)
                        }
                    }
                    .background(
                        message.role == .user ?
                            Color(red: 149/255, green: 236/255, blue: 105/255) :
                            Color.white
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    // 添加微信风格的阴影
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                    
                    if message.role == .assistant { Spacer(minLength: 60) }
                }
            }
            
            // 用户头像
            if message.role == .user {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
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
            .animation(.easeOut(duration: 0.1), value: text)
            .transition(.opacity)
    }
}