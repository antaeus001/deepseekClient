import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("隐私政策")
                            .font(.title)
                            .bold()
                        
                        Text("最后更新日期：2024年3月")
                            .foregroundColor(.gray)
                        
                        Text("感谢您使用我们的AI聊天应用。本隐私政策旨在说明我们如何收集、使用和保护您的个人信息。")
                        
                        Text("信息收集")
                            .font(.headline)
                        Text("• 聊天记录：我们会保存您与AI助手的对话内容，以提供更好的服务体验。\n• API密钥：我们会安全存储您提供的API密钥。\n• 使用数据：我们会收集应用使用情况的基本统计信息。")
                        
                        Text("信息使用")
                            .font(.headline)
                        Text("• 改进服务：我们使用收集的信息来优化和改进应用功能。\n• 个性化体验：基于您的使用习惯提供更好的服务。")
                        
                        Text("信息保护")
                            .font(.headline)
                        Text("• 数据存储：所有数据都存储在您的本地设备上。\n• 加密传输：与服务器的所有通信都经过加密。\n• 不会共享：我们不会将您的个人信息分享给第三方。")
                    }
                    
                    Group {
                        Text("您的权利")
                            .font(.headline)
                        Text("• 访问权：您可以随时查看您的聊天记录。\n• 删除权：您可以删除任何聊天记录。\n• 导出权：您可以导出您的数据。")
                        
                        Text("联系我们")
                            .font(.headline)
                        Text("如果您对隐私政策有任何疑问，请联系我们：\nsupport@example.com")
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
} 