import Foundation

class StickyCache {
    var stored: [Stickable]?
    static let shared: StickyCache = StickyCache()
    
    private init(stored: [Stickable]? = nil) {
        self.stored = stored
    }
}
