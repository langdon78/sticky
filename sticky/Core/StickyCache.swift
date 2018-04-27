import Foundation

internal let cache = StickyCache.shared

internal class StickyCache {
    var stored: [String: [Stickable]] = [:] {
        didSet {
            stickyLog("Cache updated")
        }
    }
    static let shared: StickyCache = StickyCache()
    
    private init() {}
}
