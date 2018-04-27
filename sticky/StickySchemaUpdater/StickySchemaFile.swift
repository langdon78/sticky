import Foundation

internal struct StickySchemaFile {
    public var version: Int
    public var fileUrl: URL
    
    public init(version: Int, fileUrl: URL) {
        self.version = version
        self.fileUrl = fileUrl
    }
    
    public func toStickySchemaMap() -> StickySchemaMap<String>? {
        guard let data = schemaData() else { return nil }
        guard let schemaMap = json(from: data) as? StickySchemaMap<String> else {
            stickyLog("Can not parse JSON file", logAction: .error)
            return nil
        }
        return schemaMap
    }
    
    private func schemaData() -> Data? {
        do {
            let data = try Data(contentsOf: fileUrl)
            return data
        }
        catch {
            stickyLog("Unable to process schema file \(fileUrl)", logAction: .error)
            return nil
        }
    }
    
    private func json(from data: Data) -> Any? {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json
        }
        catch {
            stickyLog("Unable to parse json for \(fileUrl)", logAction: .error)
            return nil
        }
    }
}
