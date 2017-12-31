import Foundation

public class Sticky {
    public static let shared = Sticky()
    public var configuration: StickyConfiguration
    
    private init(_ configuration: StickyConfiguration = StickyConfiguration()) {
        self.configuration = configuration
    }
}
