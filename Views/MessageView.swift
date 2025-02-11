import SwiftUI
import MarkdownUI

struct MessageView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .assistant {
                assistantMessage
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                userMessage
            }
        }
        .padding(.horizontal)
    }
    
    // AI 消息视图
    private var assistantMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // AI 头像
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                            .imageScale(.medium)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Assistant")
                        .font(.footnote)
                        .foregroundColor(.purple)
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer(minLength: 0)
            }
            
            Markdown(message.content)
                .textSelection(.enabled)
                .markdownTheme(.gitHub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
        )
        .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .leading)
    }
    
    // 用户消息视图
    private var userMessage: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("我")
                        .font(.footnote)
                        .foregroundColor(.white)
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // 用户头像
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.white)
                            .imageScale(.large)
                    )
            }
            
            Text(message.content)
                .textSelection(.enabled)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .trailing)
    }
} 