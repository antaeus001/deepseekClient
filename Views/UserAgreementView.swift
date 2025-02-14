import SwiftUI

struct UserAgreementView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("用户协议")
                            .font(.title)
                            .bold()
                        
                        Text("最后更新日期：2024年3月")
                            .foregroundColor(.gray)
                        
                        Text("欢迎使用我们的AI聊天应用。请仔细阅读以下条款。")
                        
                        Text("服务说明")
                            .font(.headline)
                        Text("• 本应用提供基于AI的对话服务。\n• 服务质量依赖于您提供的API密钥和网络状况。\n• 我们保留随时更新和改进服务的权利。")
                        
                        Text("用户责任")
                            .font(.headline)
                        Text("• 遵守法律法规。\n• 不得滥用服务或进行违法活动。\n• 保护个人账户和API密钥的安全。")
                        
                        Text("知识产权")
                            .font(.headline)
                        Text("• 应用相关的所有知识产权归我们所有。\n• 用户生成的内容归用户所有。\n• 用户授权我们使用其反馈改进服务。")
                    }
                    
                    Group {
                        Text("免责声明")
                            .font(.headline)
                        Text("• AI生成的内容可能存在错误。\n• 我们不对服务中断或数据丢失负责。\n• 用户需自行承担使用风险。")
                        
                        Text("协议修改")
                            .font(.headline)
                        Text("我们保留随时修改本协议的权利，修改后的协议将在应用内公布。")
                        
                        Text("联系方式")
                            .font(.headline)
                        Text("如有问题请联系：support@example.com")
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