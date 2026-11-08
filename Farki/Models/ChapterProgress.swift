import Foundation

struct LessonTask: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var isCompleted: Bool

    init(id: String = UUID().uuidString, title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

struct Chapter: Identifiable, Codable {
    let id: String
    let chapterNumber: Int
    let title: String
    let description: String
    var tasks: [LessonTask]

    var completionPercentage: Double {
        guard !tasks.isEmpty else { return 0.0 }
        let completed = tasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(tasks.count)
    }
}

struct ActiveBlock: Codable {
    var title: String
    var timeSlot: String
    var timeRemainingText: String
    var progress: Double // 0.0 to 1.0
    var upNextTitle: String
    var upNextTimeSlot: String
}
