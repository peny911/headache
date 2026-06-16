import Foundation

enum HeadacheFormatters {
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func duration(_ interval: TimeInterval?) -> String {
        guard let interval else { return "进行中" }
        let minutes = max(Int(interval / 60), 0)
        let hours = minutes / 60
        let restMinutes = minutes % 60
        if hours == 0 {
            return "\(restMinutes) 分钟"
        }
        if restMinutes == 0 {
            return "\(hours) 小时"
        }
        return "\(hours) 小时 \(restMinutes) 分钟"
    }
}
