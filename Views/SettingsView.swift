import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings: AppSettings
    private let deepSeekService = DeepSeekService.shared
    @State private var showPrivacyPolicy = false
    @State private var showUserAgreement = false
    
    init() {
        _settings = State(initialValue: DeepSeekService.shared.settings)
    }
    
    var body: some View {
        Form {
            Section("API 配置") {
                TextField("API 端点", text: $settings.apiEndpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: settings.apiEndpoint) { _ in
                        deepSeekService.updateSettings(value: settings)
                    }
                
                SecureField("API Key", text: $settings.apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: settings.apiKey) { _ in
                        deepSeekService.updateSettings(value: settings)
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
                Button("隐私政策") {
                    showPrivacyPolicy = true
                }
                
                Button("用户协议") {
                    showUserAgreement = true
                }
            } header: {
                Text("法律条款")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showUserAgreement) {
            UserAgreementView()
        }
    }
} 