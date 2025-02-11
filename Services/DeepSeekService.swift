import Foundation

class DeepSeekService {
    static let shared = DeepSeekService()
    var settings: AppSettings
    
    private init() {
        self.settings = UserDefaults.standard.getValue(AppSettings.self, forKey: "appSettings") ?? AppSettings.default
    }
    
    func updateSettings(value newSettings: AppSettings) {
        self.settings = newSettings
        UserDefaults.standard.setValue(newSettings, forKey: "appSettings")
    }
    
    func sendMessage(_ message: String, chatId: String) async throws -> AsyncStream<String> {
        let messages: [[String: Any]] = [
            ["role": "user", "content": message]
        ]
        
        let parameters: [String: Any] = [
            "model": "deepseek-chat",
            "messages": messages,
            "temperature": 0.7,
            "stream": true,
            "max_tokens": 2000
        ]
        
        guard let url = URL(string: "\(settings.apiEndpoint)/v1/chat/completions") else {
            print("❌ Invalid URL: \(settings.apiEndpoint)")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        print("📤 Sending request to: \(url.absoluteString)")
        
        return AsyncStream { continuation in
            Task {
                do {
                    let (stream, response) = try await URLSession.shared.bytes(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        print("📥 Response status: \(httpResponse.statusCode)")
                    }
                    
                    for try await line in stream.lines {
                        // 忽略心跳消息
                        if line == ": keep-alive" {
                            print("💓 Heartbeat received")
                            continue
                        }
                        
                        // 处理数据行
                        if line.hasPrefix("data: ") {
                            let data = line.dropFirst(6)
                            if data == "[DONE]" {
                                print("✅ Stream completed")
                                continuation.finish()
                                break
                            }
                            
                            if let jsonData = data.data(using: .utf8),
                               let response = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let choices = response["choices"] as? [[String: Any]],
                               let choice = choices.first,
                               let delta = choice["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                print("📝 Received content: \(content)")
                                continuation.yield(content)
                            }
                        }
                    }
                } catch {
                    print("❌ Stream error: \(error)")
                    continuation.finish()
                }
            }
        }
    }
} 