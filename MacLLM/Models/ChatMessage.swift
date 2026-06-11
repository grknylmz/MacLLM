import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    var content: String
}
