import Foundation

class StickyCache {
    var stored: [Persistable]?
    static let shared: StickyCache = StickyCache()
    
    private init(stored: [Persistable]? = nil) {
        self.stored = stored
    }
}
