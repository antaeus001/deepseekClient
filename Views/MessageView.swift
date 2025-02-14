import SwiftUI
import MarkdownUI

struct MessageView: View {
    let message: Message
    @State private var displayedReasoning: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.role == .assistant {
                Group {
                    if let reasoning = message.reasoningContent,
                       !reasoning.isEmpty {
                        // 推理内容
                        VStack(alignment: .leading, spacing: 4) {
                            Text("推理过程：")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(reasoning)
                                .font(.system(.body))
                                .foregroundColor(.gray)
                                .id(reasoning)  // 使用内容作为 id 来强制更新
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                }
                .animation(.easeInOut, value: message.reasoningContent)
            }
            
            // 主要内容
            MessageContentView(content: message.content)
                .textSelection(.enabled)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(message.role == .assistant ? Color(.systemBackground) : Color.blue)
        )
        .padding(.horizontal)
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