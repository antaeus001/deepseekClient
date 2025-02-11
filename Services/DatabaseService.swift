import Foundation
import SQLite

class DatabaseService {
    static let shared = DatabaseService()
    private var db: Connection?
    
    // 表定义
    private let chats = Table("chats")
    private let messages = Table("messages")
    
    // Chats 表列定义
    private let chatId = Expression<String>(value: "id")
    private let chatTitle = Expression<String>(value: "title")
    private let chatCreatedAt = Expression<String>(value: "created_at")
    private let chatUpdatedAt = Expression<String>(value: "updated_at")
    
    // Messages 表列定义
    private let messageId = Expression<String>(value: "id")
    private let messageContent = Expression<String>(value: "content")
    private let messageRole = Expression<String>(value: "role")
    private let messageChatId = Expression<String>(value: "chat_id")
    private let messageTimestamp = Expression<String>(value: "timestamp")
    private let messageStatus = Expression<String>(value: "status")
    
    // 日期格式化器
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first!
        
        do {
            db = try Connection("\(path)/deepseek.sqlite3")
            try createTables()
        } catch {
            print("Database connection error: \(error)")
        }
    }
    
    private func createTables() throws {
        try db?.execute("""
            CREATE TABLE IF NOT EXISTS chats (
                id TEXT PRIMARY KEY,
                title TEXT,
                created_at TEXT,
                updated_at TEXT
            )
        """)
        
        try db?.execute("""
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                content TEXT,
                role TEXT,
                chat_id TEXT,
                timestamp TEXT,
                status TEXT,
                FOREIGN KEY(chat_id) REFERENCES chats(id)
            )
        """)
    }
    
    // CRUD 操作
    func saveChat(_ chat: Chat) throws {
        let sql = """
            INSERT OR REPLACE INTO chats (id, title, created_at, updated_at)
            VALUES (?, ?, ?, ?)
        """
        try db?.run(sql, [
            chat.id,
            chat.title,
            dateFormatter.string(from: chat.createdAt),
            dateFormatter.string(from: chat.updatedAt)
        ])
        
        for message in chat.messages {
            try saveMessage(value: message, chatId: chat.id)
        }
    }
    
    func saveMessage(value message: Message, chatId: String) throws {
        let sql = """
            INSERT OR REPLACE INTO messages (id, content, role, chat_id, timestamp, status)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        try db?.run(sql, [
            message.id,
            message.content,
            message.role.rawValue,
            chatId,
            dateFormatter.string(from: message.timestamp),
            message.status.rawValue
        ])
    }
    
    // 查询方法
    func getChat(id: String) throws -> Chat? {
        let query = chats.filter(chatId == id)
        guard let row = try db?.pluck(query) else { return nil }
        
        return Chat(
            id: row[chatId],
            title: row[chatTitle],
            createdAt: dateFormatter.date(from: row[chatCreatedAt]) ?? Date(),
            updatedAt: dateFormatter.date(from: row[chatUpdatedAt]) ?? Date(),
            messages: try getMessages(chatId: id)
        )
    }
    
    func getMessages(chatId: String) throws -> [Message] {
        let query = messages.filter(messageChatId == chatId)
        let rows = try db?.prepare(query)
        
        return try rows?.map { row in
            Message(
                id: row[messageId],
                content: row[messageContent],
                role: MessageRole(rawValue: row[messageRole])!,
                timestamp: dateFormatter.date(from: row[messageTimestamp]) ?? Date(),
                status: MessageStatus(rawValue: row[messageStatus])!
            )
        } ?? []
    }
    
    // 调试方法
    func debugPrintDatabasePath() {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first!
        print("Database path: \(path)/deepseek.sqlite3")
    }
    
    func debugPrintAllData() throws {
        print("\n=== Chats ===")
        if let chatRows = try db?.prepare(chats) {
            for row in chatRows {
                print("Chat ID: \(row[chatId])")
                print("Title: \(row[chatTitle])")
                print("Created At: \(row[chatCreatedAt])")
                print("Updated At: \(row[chatUpdatedAt])")
                print("---")
            }
        }
        
        print("\n=== Messages ===")
        if let messageRows = try db?.prepare(messages) {
            for row in messageRows {
                print("Message ID: \(row[messageId])")
                print("Content: \(row[messageContent])")
                print("Role: \(row[messageRole])")
                print("Chat ID: \(row[messageChatId])")
                print("Timestamp: \(row[messageTimestamp])")
                print("Status: \(row[messageStatus])")
                print("---")
            }
        }
    }
    
    func debugReadDatabase() {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first!
        let dbPath = "\(path)/deepseek.sqlite3"
        
        print("Database path: \(dbPath)")
        
        // 尝试读取文件内容
        if let data = try? Data(contentsOf: URL(fileURLWithPath: dbPath)),
           let content = String(data: data, encoding: .utf8) {
            print("Database content:\n\(content)")
        } else {
            print("Could not read database file")
        }
    }
} 