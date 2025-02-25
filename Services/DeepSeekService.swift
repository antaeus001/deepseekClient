import Foundation

class DeepSeekService {
    static let shared = DeepSeekService()
    var settings: AppSettings
    private var currentModel: String
    private var isDeepThinking = false  // 默认为 false
    
    private init() {
        self.settings = UserDefaults.standard.getValue(AppSettings.self, forKey: "appSettings") ?? AppSettings.default
        self.currentModel = settings.chatModel  // 默认使用会话模型
    }
    
    func updateSettings(value newSettings: AppSettings) {
        self.settings = newSettings
        UserDefaults.standard.setValue(newSettings, forKey: "appSettings")
        self.currentModel = isDeepThinking ? settings.reasonerModel : settings.chatModel
    }
    
    func setModel(_ isReasoner: Bool) {
        isDeepThinking = isReasoner
        currentModel = isReasoner ? settings.reasonerModel : settings.chatModel
    }
    
    func sendMessage(_ content: String, chatId: String, history: [[String: String]] = []) async throws -> AsyncThrowingStream<(String, String?), Error> {
        // 合并历史消息和当前消息
        var messages = history
        messages.append(["role": "user", "content": content])
        
        let parameters: [String: Any] = [
            "model": currentModel,
            "messages": messages,
            "stream": true,
            // OpenAI 标准参数
            "temperature": 0.7,
            "max_tokens": 2000,
            "top_p": 1.0,
            "frequency_penalty": 0,
            "presence_penalty": 0
        ]
        
        print("📤 发送请求: \(parameters)")
        print("🔄 消息历史数量: \(messages.count)")
        
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
        
        // 添加调试信息
        if let body = String(data: request.httpBody!, encoding: .utf8) {
            print("📦 请求体: \(body)")
        }
        
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
    private var hasStartedStreaming = false
    
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
        
        let lines = (buffer + text).components(separatedBy: "\n")
        buffer = lines.last ?? ""
        
        for line in lines.dropLast() {
            if line.isEmpty { continue }
            if !line.hasPrefix("data: ") { continue }
            
            let data = String(line.dropFirst(6))
            if data == "[DONE]" {
                isCompleted = true
                continuation.finish()
                return
            }
            
            if let jsonData = data.data(using: .utf8),
               let response = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let choices = response["choices"] as? [[String: Any]],
               let choice = choices.first,
               let delta = choice["delta"] as? [String: Any] {
                
                var content = ""
                var shouldYield = false
                
                if let reasoningFlag = delta["reasoning_flag"] as? Bool {
                    isReasoning = reasoningFlag
                    hasReasoningFlag = true
                }
                
                if let reasoningContent = delta["reasoning_content"] as? String {
                    self.reasoningContent += reasoningContent
                    shouldYield = true
                }
                
                if let deltaContent = delta["content"] as? String {
                    content = deltaContent
                    shouldYield = true
                }
                
                if shouldYield {
                    if !hasStartedStreaming {
                        hasStartedStreaming = true
                        continuation.yield(("", nil))
                    }
                    continuation.yield((content, self.reasoningContent))
                }
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