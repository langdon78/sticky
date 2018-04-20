import Foundation

internal enum FileResult {
    case success
    case error(Error)
}

internal class FileHandler {
    private static var localDirectory: URL {
        return Sticky.shared.configuration.localDirectory
    }
    
    private static var fileExtensionName: String {
        return Sticky.shared.configuration.fileExtensionName
    }
    
    internal static func url(for persistantObjectName: String) -> URL {
        var configuredUrl = FileHandler.localDirectory
        let fileName = persistantObjectName
        let fileExtension = FileHandler.fileExtensionName
        configuredUrl.appendPathComponent(fileName + fileExtension)
        return configuredUrl
    }
    
    internal static func fileExists(at path: String) -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: path)
    }
    
    internal static func renameFile(from oldName: String, to newName: String) -> FileResult {
        let originPath = url(for: oldName)
        let destinationPath = url(for: newName)
        do {
            try FileManager.default.moveItem(at: originPath, to: destinationPath)
            return .success
        }
        catch {
            return .error(error)
        }
    }
    
    internal static func read(from path: String) -> Data? {
        guard fileExists(at: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        do {
            stickyLog("Read from file")
            return try Data(contentsOf: url)
        } catch {
            stickyLog("ERROR: \(error.localizedDescription)", logAction: .error)
            return nil
        }
    }
    
    @discardableResult internal static func write(data: Data, to path: String) -> FileResult {
        do {
            try data.write(to: URL(fileURLWithPath: path))
            stickyLog("File updated")
            return .success
        } catch let error {
            return .error(error)
        }
    }
    
    internal static func clear() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: localDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            urls.forEach { url in
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    print(error.localizedDescription)
                }
            }
        } catch {
            stickyLog(error.localizedDescription, logAction: .error)
        }
    }
}
