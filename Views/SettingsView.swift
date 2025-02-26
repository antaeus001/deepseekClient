import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings: AppSettings
    private let deepSeekService = DeepSeekService.shared
    @State private var showApiKey = false
    
    init() {
        _settings = State(initialValue: DeepSeekService.shared.settings)
    }
    
    var body: some View {
        Form {
            Section {
                TextField("API 端点", text: $settings.apiEndpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: settings.apiEndpoint) { _ in
                        deepSeekService.updateSettings(value: settings)
                    }
                
                HStack {
                    if showApiKey {
                        TextField("API Key", text: $settings.apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: settings.apiKey) { _ in
                                deepSeekService.updateSettings(value: settings)
                            }
                    } else {
                        SecureField("API Key", text: $settings.apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: settings.apiKey) { _ in
                                deepSeekService.updateSettings(value: settings)
                            }
                    }
                    
                    Button {
                        showApiKey.toggle()
                    } label: {
                        Image(systemName: showApiKey ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                    }
                }
            } header: {
                Text("API 配置")
            } footer: {
                HStack {
                    Spacer()
                    Link("查看配置帮助", destination: URL(string: "https://www.huohuaai.com/api_help.html")!)
                        .font(.footnote)
                }
            }
            
            Section("模型配置") {
                TextField("对话模型", text: $settings.chatModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: settings.chatModel) { _ in
                        deepSeekService.updateSettings(value: settings)
                    }
                
                TextField("推理模型", text: $settings.reasonerModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: settings.reasonerModel) { _ in
                        deepSeekService.updateSettings(value: settings)
                    }
            }
            
            Section {
                Link("隐私政策", destination: URL(string: "https://www.huohuaai.com/privacy-deepseekclient.html")!)
                    .foregroundColor(.primary)
                
                Link("用户协议", destination: URL(string: "https://www.huohuaai.com/terms-deepseekclient.html")!)
                    .foregroundColor(.primary)
            } header: {
                Text("法律条款")
            }
        }
        .navigationTitle("设置")
    }
} 