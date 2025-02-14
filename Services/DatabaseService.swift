import Foundation
import SQLite

class DatabaseService {
    static let shared = DatabaseService()
    private var db: Connection?
    private let store = NSUbiquitousKeyValueStore.default
    
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
    private let messageReasoningContent = Expression<String?>(value: "reasoning_content")
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
            try migrateDatabase()
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
                reasoning_content TEXT,
                role TEXT,
                chat_id TEXT,
                timestamp TEXT,
                status TEXT,
                FOREIGN KEY(chat_id) REFERENCES chats(id)
            )
        """)
    }
    
    private func migrateDatabase() throws {
        // 检查是否需要迁移
        let tableInfo = try db?.prepare("PRAGMA table_info(messages)")
        let hasReasoningContent = tableInfo?.contains { row in
            let name = row[1] as? String
            return name == "reasoning_content"
        } ?? false
        
        if !hasReasoningContent {
            print("Migrating database to add reasoning_content column...")
            
            try db?.transaction {
                // 1. 重命名旧表
                try db?.execute("ALTER TABLE messages RENAME TO messages_old")
                
                // 2. 创建新表
                try db?.execute("""
                    CREATE TABLE messages (
                        id TEXT PRIMARY KEY,
                        content TEXT,
                        reasoning_content TEXT,
                        role TEXT,
                        chat_id TEXT,
                        timestamp TEXT,
                        status TEXT,
                        FOREIGN KEY(chat_id) REFERENCES chats(id)
                    )
                """)
                
                // 3. 复制数据
                try db?.execute("""
                    INSERT INTO messages (id, content, reasoning_content, role, chat_id, timestamp, status)
                    SELECT id, content, NULL, role, chat_id, timestamp, status
                    FROM messages_old
                """)
                
                // 4. 删除旧表
                try db?.execute("DROP TABLE messages_old")
            }
            
            print("Database migration completed successfully")
        }
    }
    
    // CRUD 操作
    func saveChat(_ chat: Chat) throws {
        let insert = """
            INSERT OR REPLACE INTO chats (id, title, created_at, updated_at)
            VALUES (?, ?, ?, ?)
        """
        try db?.run(insert, [
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
            INSERT OR REPLACE INTO messages (id, content, reasoning_content, role, chat_id, timestamp, status)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        try db?.run(sql, [
            message.id,
            message.content,
            message.reasoningContent,
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
    
    func fetchChats() async throws -> [Chat] {
        guard let db = db else {
            throw DatabaseError.connectionError
        }
        
        var result: [Chat] = []
        
        let query = """
            SELECT id, title, created_at, updated_at 
            FROM chats 
            ORDER BY updated_at DESC
        """
        
        let rows = try db.prepare(query)
        for row in rows {
            let chatId = row[0] as! String
            let messages = try getMessages(chatId: chatId)
            
            let chat = Chat(
                id: chatId,
                title: row[1] as! String,
                createdAt: dateFormatter.date(from: row[2] as! String) ?? Date(),
                updatedAt: dateFormatter.date(from: row[3] as! String) ?? Date(),
                messages: messages
            )
            result.append(chat)
        }
        return result
    }
    
    func deleteChat(_ chat: Chat) throws {
        let deleteMessages = "DELETE FROM messages WHERE chat_id = ?"
        let deleteChat = "DELETE FROM chats WHERE id = ?"
        
        try db?.run(deleteMessages, [chat.id])
        try db?.run(deleteChat, [chat.id])
    }
    
    private func getMessages(chatId: String) throws -> [Message] {
        let query = """
            SELECT id, content, reasoning_content, role, chat_id, timestamp, status 
            FROM messages 
            WHERE chat_id = ? 
            ORDER BY timestamp ASC
        """
        
        let rows = try db?.prepare(query, [chatId])
        return try rows?.map { row in
            Message(
                id: row[0] as! String,
                content: row[1] as! String,
                reasoningContent: row[2] as? String,
                role: MessageRole(rawValue: row[3] as! String)!,
                timestamp: dateFormatter.date(from: row[5] as! String) ?? Date(),
                status: MessageStatus(rawValue: row[6] as! String) ?? .success
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
                print("Reasoning Content: \(row[messageReasoningContent] ?? "None")")
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

// 添加错误类型
enum DatabaseError: Error {
    case connectionError
    case queryError
    case insertError
    case updateError
    case deleteError
} 