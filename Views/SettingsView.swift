import SwiftUI

struct SettingsView: View {
    @State private var settings: AppSettings
    @State private var showPrivacyPolicy = false
    @State private var showUserAgreement = false
    
    init() {
        // 初始化时从 DeepSeekService 获取设置
        _settings = State(initialValue: DeepSeekService.shared.settings)
    }
    
    var body: some View {
        Form {
            Section(header: Text("API 配置")) {
                TextField("API 地址", text: $settings.apiEndpoint)
                SecureField("API Key", text: $settings.apiKey)
            }
            
            Button("保存") {
                DeepSeekService.shared.updateSettings(value: settings)
            }
            
            Section("法律条款") {
                Button("隐私政策") {
                    showPrivacyPolicy = true
                }
                
                Button("用户协议") {
                    showUserAgreement = true
                }
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showUserAgreement) {
            UserAgreementView()
        }
    }
} 