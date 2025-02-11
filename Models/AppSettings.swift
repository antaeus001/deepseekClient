import Foundation

struct AppSettings: Codable {
    var apiEndpoint: String
    var apiKey: String
    
    static let `default` = AppSettings(
        apiEndpoint: "https://api.deepseek.com",
        apiKey: ""
    )
} 