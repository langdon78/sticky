import Foundation

public let defaultFileExtension = ".json"

public struct StickyConfiguration {
    public let localDirectory: URL
    public let preloadCache: Bool
    public let fileExtensionName: String
    public let clearDirectory: Bool
    public let async: Bool
    
    public init(
        localDirectory: URL = try!
            FileManager.default.url(
                for: .documentDirectory,
                in: .allDomainsMask,
                appropriateFor: nil,
                create: false
            ),
        preloadCache: Bool = true,
        fileExtensionName: String = defaultFileExtension,
        clearDirectory: Bool = false,
        async: Bool = false
        ) {
        self.localDirectory = localDirectory
        self.preloadCache = preloadCache
        self.fileExtensionName = fileExtensionName
        self.clearDirectory = clearDirectory
        self.async = async
    }
}
