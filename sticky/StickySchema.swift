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

public class StickySchema: StickySchemable {
    public var version: Int
    public var schemaFileData: Data
    
    init(version: Int, schemaFileData: Data) {
        self.version = version
        self.schemaFileData = schemaFileData
    }
    
    func updateEntityName(from oldName: String, to newName: String) {
        FileHandler.renameFile(from: oldName, to: newName)
    }
    
    public static func readSchemaFile(_ file: StickySchemaFile) -> StickySchema? {
        guard let data = try? Data(contentsOf: file.fileUrl) else { return nil }
        return StickySchema(version: file.version, schemaFileData: data)
    }
    
    public func process() {
        let json = try? JSONSerialization.jsonObject(with: schemaFileData, options: [])
        guard
            let dict = json as? [String: Any],
            let version = dict["version"] as? Int,
            let entityUpdate = dict["entityNameUpdate"] as? [String: String]
            else { return }
        
        for (oldName, newName) in entityUpdate {
            updateEntityName(from: oldName, to: newName)
        }
    }
}
