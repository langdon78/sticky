import Foundation

internal struct StickyConfiguration {
    let localDirectory: URL
    let preloadCache: Bool
    let fileExtensionName: String
    let clearDirectory: Bool
    let async: Bool
    
    init(
        localDirectory: URL = try!
            FileManager.default.url(
                for: .documentDirectory,
                in: .allDomainsMask,
                appropriateFor: nil,
                create: false
            ),
        preloadCache: Bool = true,
        fileExtensionName: String = ".json",
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
