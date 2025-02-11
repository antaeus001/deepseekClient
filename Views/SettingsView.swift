import SwiftUI

struct SettingsView: View {
    @State private var settings: AppSettings
    
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
        }
        .navigationTitle("设置")
    }
} 