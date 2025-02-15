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
    
    func sendMessage(_ content: String, chatId: String) async throws -> AsyncThrowingStream<(String, String?), Error> {
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
            print("📤 发送请求: \(jsonString)")
        }
        
        guard let url = URL(string: "\(settings.apiEndpoint)/v1/chat/completions") else {
            print("❌ 无效的 URL: \(settings.apiEndpoint)/v1/chat/completions")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        print("🌐 API 端点: \(settings.apiEndpoint)")
        print("🔑 API Key: \(settings.apiKey.prefix(8))...")
        
        return AsyncThrowingStream { continuation in
            let delegate = StreamDelegate(continuation: continuation)
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            
            let task = session.dataTask(with: request)
            task.resume()
            
            continuation.onTermination = { _ in
                print("🛑 流式请求被终止")
                task.cancel()
                session.invalidateAndCancel()
            }
        }
    }
}

private class StreamDelegate: NSObject, URLSessionDataDelegate {
    let continuation: AsyncThrowingStream<(String, String?), Error>.Continuation
    private var buffer = ""
    private var isCompleted = false
    private var reasoningContent = ""
    private var isReasoning = false
    private var hasReasoningFlag = false
    
    init(continuation: AsyncThrowingStream<(String, String?), Error>.Continuation) {
        self.continuation = continuation
        super.init()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !isCompleted else { return }
        guard let text = String(data: data, encoding: .utf8) else {
            print("❌ 无法解码接收到的数据")
            return
        }
        
        print("📥 收到原始数据: \(text)")
        
        let lines = (buffer + text).components(separatedBy: "\n")
        buffer = lines.last ?? ""
        
        for line in lines.dropLast() {
            if line.isEmpty { 
                print("⏭️ 跳过空行")
                continue 
            }
            if !line.hasPrefix("data: ") { 
                print("⚠️ 非数据行: \(line)")
                continue 
            }
            
            let data = String(line.dropFirst(6))
            if data == "[DONE]" {
                print("✅ 流式响应完成")
                isCompleted = true
                continuation.finish()
                return
            }
            
            print("🔍 解析数据行: \(data)")
            
            if let jsonData = data.data(using: .utf8),
               let response = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let choices = response["choices"] as? [[String: Any]],
               let choice = choices.first,
               let delta = choice["delta"] as? [String: Any] {
                
                print("🔄 解析成功: \(delta)")
                
                var content = ""
                var shouldYield = false
                
                if let reasoningFlag = delta["reasoning_flag"] as? Bool {
                    isReasoning = reasoningFlag
                    hasReasoningFlag = true
                    print("🚩 推理标志变更: \(isReasoning)")
                }
                
                if let reasoningContent = delta["reasoning_content"] as? String {
                    self.reasoningContent += reasoningContent
                    print("💭 推理内容更新: \(self.reasoningContent)")
                    shouldYield = true  // 有推理内容更新时也要触发
                }
                
                if let deltaContent = delta["content"] as? String {
                    content = deltaContent
                    print("📝 内容更新: \(content)")
                    shouldYield = true
                }
                
                if shouldYield {
                    // 只要有任何更新就发送
                    continuation.yield((content, self.reasoningContent))
                }
            } else {
                print("❌ JSON 解析失败: \(data)")
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if !isCompleted {
            if let error = error {
                print("❌ 流式响应错误: \(error)")
                continuation.finish(throwing: error)
            } else {
                print("✅ 流式响应正常完成")
                continuation.finish()
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
} 