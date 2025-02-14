import Foundation

class DeepSeekService {
    static let shared = DeepSeekService()
    var settings: AppSettings
    private var currentModel = "deepseek-chat"
    
    private init() {
        self.settings = UserDefaults.standard.getValue(AppSettings.self, forKey: "appSettings") ?? AppSettings.default
    }
    
    func updateSettings(value newSettings: AppSettings) {
        self.settings = newSettings
        UserDefaults.standard.setValue(newSettings, forKey: "appSettings")
    }
    
    func setModel(_ model: String) {
        currentModel = model
    }
    
    func sendMessage(_ content: String, chatId: String) async throws -> AsyncThrowingStream<String, Error> {
        let messages = [
            ["role": "user", "content": content]
        ]
        
        let parameters: [String: Any] = [
            "model": currentModel,
            "messages": messages,
            "stream": true
        ]
        
        // 打印请求内容
        if let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Request body: \(jsonString)")
        }
        
        guard let url = URL(string: "\(settings.apiEndpoint)/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        return AsyncThrowingStream { continuation in
            let delegate = StreamDelegate(continuation: continuation)
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            
            let task = session.dataTask(with: request)
            task.resume()
            
            continuation.onTermination = { _ in
                task.cancel()
                session.invalidateAndCancel()
            }
        }
    }
}

private class StreamDelegate: NSObject, URLSessionDataDelegate {
    let continuation: AsyncThrowingStream<String, Error>.Continuation
    private var buffer = ""
    private var isCompleted = false  // 添加标志来跟踪是否已完成
    
    init(continuation: AsyncThrowingStream<String, Error>.Continuation) {
        self.continuation = continuation
        super.init()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !isCompleted,  // 检查是否已完成
              let text = String(data: data, encoding: .utf8) else { return }
        
        // 处理接收到的数据
        let lines = (buffer + text).components(separatedBy: "\n")
        buffer = lines.last ?? ""
        
        for line in lines.dropLast() {
            if line.isEmpty { continue }
            if !line.hasPrefix("data: ") { continue }
            
            let data = String(line.dropFirst(6))
            if data == "[DONE]" {
                print("✅ Stream completed")
                isCompleted = true  // 标记为已完成
                continuation.finish()
                return
            }
            
            if let jsonData = data.data(using: .utf8),
               let response = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let choices = response["choices"] as? [[String: Any]],
               let choice = choices.first,
               let delta = choice["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                continuation.yield(content)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // 只有在未完成且有错误时才处理
        if !isCompleted {
            if let error = error {
                print("❌ Stream error: \(error)")
            }
            continuation.finish()
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
} 