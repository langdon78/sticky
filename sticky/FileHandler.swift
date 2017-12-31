import Foundation

internal class FileHandler {
    private static var localDirectory: URL {
        return Sticky.shared.configuration.localDirectory
    }
    
    private static var fileExtensionName: String {
        return Sticky.shared.configuration.fileExtensionName
    }
    
    internal static func fullPath(for persistantObject: Persistable.Type) -> String {
        var configuredUrl = FileHandler.localDirectory
        let fileName = String(describing: persistantObject)
        let fileExtension = FileHandler.fileExtensionName
        configuredUrl.appendPathComponent(fileName + fileExtension)
        let path = configuredUrl.path
        return path
    }
    
    internal static func read(from path: String) -> Data? {
        return FileManager.default.contents(atPath: path)
    }
    
    internal static func write(data: Data, to path: String) {
        do {
            try data.write(to: URL(fileURLWithPath: path))
        } catch let error {
            print(error.localizedDescription)
        }
    }
}
