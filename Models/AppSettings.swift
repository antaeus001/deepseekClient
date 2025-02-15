import Foundation

struct AppSettings: Codable {
    var apiEndpoint: String
    var apiKey: String
    var chatModel: String  // 普通对话模型
    var reasonerModel: String  // 推理模型
    
    static let `default` = AppSettings(
        apiEndpoint: "https://api.deepseek.com",
        apiKey: "",
        chatModel: "deepseek-chat",
        reasonerModel: "deepseek-reasoner"
    )
} 