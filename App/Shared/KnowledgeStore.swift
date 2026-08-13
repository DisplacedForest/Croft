import Foundation
import Knowledge

enum KnowledgeStore {
    static func openBundled() -> KnowledgeSnapshot? {
        guard let url = Bundle.main.url(forResource: "knowledge", withExtension: "sqlite") else {
            return nil
        }
        return try? KnowledgeSnapshot.open(at: url)
    }
}
