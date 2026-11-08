import Foundation

enum JLPTLevel: String, CaseIterable, Identifiable, Codable {
    case all = "ALL"
    case n5 = "N5"
    case n4 = "N4"
    case n3 = "N3"
    case n2 = "N2"
    case n1 = "N1"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All Levels"
        case .n5: return "JLPT N5 (Beginner)"
        case .n4: return "JLPT N4 (Elementary)"
        case .n3: return "JLPT N3 (Intermediate)"
        case .n2: return "JLPT N2 (Pre-Advanced)"
        case .n1: return "JLPT N1 (Advanced)"
        }
    }

    var shortLabel: String { rawValue }
}
