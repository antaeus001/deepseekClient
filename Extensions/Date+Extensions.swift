import Foundation

extension Date {
    func timeAgoDisplay() -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.second, .minute, .hour, .day], from: self, to: now)
        
        if let day = components.day, day > 0 {
            if day > 7 {
                // 超过一周显示具体日期
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd"
                return formatter.string(from: self)
            }
            return "\(day)天前"
        }
        
        if let hour = components.hour, hour > 0 {
            return "\(hour)小时前"
        }
        
        if let minute = components.minute, minute > 0 {
            return "\(minute)分钟前"
        }
        
        if let second = components.second, second > 30 {
            return "1分钟内"
        }
        
        return "刚刚"
    }
} 