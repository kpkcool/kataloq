import Foundation

extension Array where Element == Product {
    /// Removes repeated product IDs, keeping the first occurrence and the original order.
    /// The backend already guarantees unique products; this only stops a malformed response
    /// from crashing a diffable data source (which traps on duplicate items).
    func uniquedByID() -> [Product] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}
