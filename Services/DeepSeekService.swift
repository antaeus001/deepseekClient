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
        // 打印当前设置
        print("API Endpoint: \(settings.apiEndpoint)")
        print("API Key: \(settings.apiKey)")
        
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
        
        // 打印请求参数
        print("Request parameters: \(parameters)")
        
        guard let url = URL(string: "\(settings.apiEndpoint)/v1/chat/completions") else {
            print("Invalid URL")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        // 打印完整请求
        print("Request URL: \(request.url?.absoluteString ?? "")")
        print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = request.httpBody {
            print("Request Body: \(String(data: body, encoding: .utf8) ?? "")")
        }
        
        return AsyncStream { continuation in
            Task {
                do {
                    let (stream, response) = try await URLSession.shared.bytes(for: request)
                    
                    // 打印响应状态
                    if let httpResponse = response as? HTTPURLResponse {
                        print("Response status code: \(httpResponse.statusCode)")
                        print("Response headers: \(httpResponse.allHeaderFields)")
                    }
                    
                    for try await line in stream.lines {
                        // 打印原始响应
                        print("Raw line: \(line)")
                        
                        if line == "data: [DONE]" {
                            print("Stream completed")
                            continuation.finish()
                            break
                        }
                        
                        guard line.hasPrefix("data: "),
                              let data = line.dropFirst(6).data(using: .utf8) else {
                            continue
                        }
                        
                        // 打印解析的 JSON
                        if let jsonString = String(data: data, encoding: .utf8) {
                            print("Parsed JSON: \(jsonString)")
                        }
                        
                        do {
                            let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            let choices = response?["choices"] as? [[String: Any]]
                            let choice = choices?.first
                            let delta = choice?["delta"] as? [String: Any]
                            
                            if let content = delta?["content"] as? String {
                                print("Yielding content: \(content)")
                                continuation.yield(content)
                            }
                        } catch {
                            print("JSON parsing error: \(error)")
                        }
                    }
                } catch {
                    print("Stream error: \(error)")
                    continuation.finish()
                }
            }
        }
    }
} 