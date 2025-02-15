import SwiftUI

struct APIHelpView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("阿里云:")
                        .font(.headline)
                    Text("API 端点: https://dashscope.aliyuncs.com/compatible-mode")
                    Text("会话模型: deepseek-v3")
                    Text("推理模型: deepseek-r1")
                    Link("申请 API Key", destination: URL(string: "https://bailian.console.aliyun.com/detail/deepseek-r1#/model-market/detail/deepseek-r1")!)
                        .foregroundColor(.blue)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.blue, lineWidth: 1)
                                .padding(.horizontal, -8)
                                .padding(.vertical, -2)
                        )
                }
                .padding(.vertical, 8)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DeepSeek 官方:")
                        .font(.headline)
                    Text("API 端点: https://api.deepseek.com")
                    Text("会话模型: deepseek-chat")
                    Text("推理模型: deepseek-reasoner")
                    Link("申请 API Key", destination: URL(string: "https://platform.deepseek.com/api_keys")!)
                        .foregroundColor(.blue)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.blue, lineWidth: 1)
                                .padding(.horizontal, -8)
                                .padding(.vertical, -2)
                        )
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("API 配置帮助")
        .navigationBarTitleDisplayMode(.inline)
    }
} 