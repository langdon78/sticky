import Foundation

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
    
    internal static func renameFile(from oldName: String, to newName: String) -> Bool {
        let originPath = url(for: oldName)
        let destinationPath = url(for: newName)
        do {
            try FileManager.default.moveItem(at: originPath, to: destinationPath)
            stickyLog("Entity changed from \(oldName) to \(newName)")
            return true
        }
        catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    internal static func read(from path: String) -> Data? {
        guard fileExists(at: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        do {
            stickyLog("Read from file")
            return try Data(contentsOf: url)
        } catch {
            stickyLog("ERROR: \(error.localizedDescription)")
            return nil
        }
    }
    
    internal static func write(data: Data, to path: String) {
        do {
            try data.write(to: URL(fileURLWithPath: path))
            stickyLog("File updated")
        } catch let error {
            print(error.localizedDescription)
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
            print(error.localizedDescription)
        }
    }
}
