import SwiftUI

struct SettingsView: View {
    @State private var settings: AppSettings
    @State private var showPrivacyPolicy = false
    @State private var showUserAgreement = false
    
    init() {
        _settings = State(initialValue: DeepSeekService.shared.settings)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("API 地址", text: $settings.apiEndpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: settings.apiEndpoint) { _ in
                            DeepSeekService.shared.updateSettings(value: settings)
                        }
                    
                    SecureField("API Key", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: settings.apiKey) { _ in
                            DeepSeekService.shared.updateSettings(value: settings)
                        }
                } header: {
                    Text("API 配置")
                } footer: {
                    Text("配置信息会自动保存")
                        .font(.caption)
                        .foregroundColor(.gray)
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
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showUserAgreement) {
            UserAgreementView()
        }
    }
} 