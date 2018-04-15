import Foundation

public struct StickySchemaFile {
    public var version: Int
    public var fileUrl: URL
    
    public init(version: Int, fileUrl: URL) {
        self.version = version
        self.fileUrl = fileUrl
    }
}

protocol StickySchemable {
    var version: Int { get set }
    
    func updateEntityName(from oldName: String, to newName: String)
    static func readSchemaFile(_ file: StickySchemaFile) -> StickySchema?
}

public class StickySchema {
    public var version: Int
    public var schemaFileData: Data
    
    init(version: Int, schemaFileData: Data) {
        self.version = version
        self.schemaFileData = schemaFileData
    }
    
    public static func readSchemaFile(_ file: StickySchemaFile) -> StickySchema? {
        guard let data = try? Data(contentsOf: file.fileUrl) else { return nil }
        return StickySchema(version: file.version, schemaFileData: data)
    }
    
    public func process() {
        let json = try? JSONSerialization.jsonObject(with: schemaFileData, options: [])
        guard let dict = json as? [String: Any] else {
            stickyLog("ERROR: Can not parse JSON file")
            return
        }
        guard let fileVersion = dict["version"] as? Int else {
            stickyLog("ERROR: Missing file version number")
            return
        }
        guard fileVersion == self.version else {
                stickyLog("ERROR: Version number \(self.version) does not match file version (\(fileVersion))")
            return
        }
        
        // Update entity name
        if let entityUpdate = dict["entityNameUpdate"] as? [String: String] {
            for (oldName, newName) in entityUpdate {
                if !FileHandler.renameFile(from: oldName, to: newName) {
                    return
                }
            }
            Sticky.shared.incrementSchemaVersion(to: version)
        }
    }
    
    public static func processUpdates(for schemaFiles: [StickySchemaFile]) {
        schemaFiles
        .sorted { $0.version < $1.version }
            .compactMap { schemaFile in
                StickySchema.readSchemaFile(schemaFile)
            }
            .forEach { stickySchema in
                stickySchema.process()
        }
    }
    
    public static func checkUpdateNeeded(for version: Int) -> Bool {
        return version != Sticky.shared.currentSchemaVersion
    }
}
