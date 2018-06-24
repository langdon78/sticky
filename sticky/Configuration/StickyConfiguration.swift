import Foundation

public let defaultFileExtension = ".json"
fileprivate let defaultBundleId = "com.sticky"

public struct StickyConfiguration {
    public let localDirectory: URL
    public let preloadCache: Bool
    public let fileExtensionName: String
    public let clearDirectory: Bool
    public let async: Bool
    public let logStyle: StickyLogStyle
    public let rollbackToSchemaVersion: Int?
    public static var defaultDirectory: URL! {
        do {
            // Using /Library/Application Support/ for app data files
            // backed up by iCloud
            // https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html
            var appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .allDomainsMask,
                appropriateFor: nil,
                create: true
            )
            // Create subdirectory for bundleId
            appSupport = appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? defaultBundleId, isDirectory: true)
            if !FileManager.default.fileExists(atPath: appSupport.path) {
                try FileManager.default.createDirectory(at: appSupport,
                                     withIntermediateDirectories: false)
            }
            
            return appSupport
        }
        catch {
            stickyLog(error)
        }
        return nil
    }
    
    public init(
        localDirectory: URL = defaultDirectory,
        preloadCache: Bool = true,
        fileExtensionName: String = defaultFileExtension,
        clearDirectory: Bool = false,
        async: Bool = false,
        logStyle: StickyLogStyle = .none,
        schemaVersion: Int = 1,
        rollbackToSchemaVersion: Int? = nil
        ) {
        self.localDirectory = localDirectory
        self.preloadCache = preloadCache
        self.fileExtensionName = fileExtensionName
        self.clearDirectory = clearDirectory
        self.async = async
        self.logStyle = logStyle
        self.rollbackToSchemaVersion = rollbackToSchemaVersion
    }
}
