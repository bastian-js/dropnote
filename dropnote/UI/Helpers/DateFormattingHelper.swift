import Foundation

struct DateFormattingHelper {
    static func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "today, " + formatter.string(from: date)
        }
        
        if calendar.isDateInYesterday(date) {
            return "yesterday"
        }
        
        let daysDifference = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if daysDifference < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: date)
    }
}
