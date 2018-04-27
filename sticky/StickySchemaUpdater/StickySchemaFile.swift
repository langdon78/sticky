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
            StickyError.invalidJson.outputToLog(schemaLog)
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
            StickyError.unableToProcessSchemaFile(fileUrl.absoluteString).outputToLog(schemaLog)
            return nil
        }
    }
    
    private func json(from data: Data) -> Any? {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json
        }
        catch {
            StickyError.unableToProcessSchemaFile(fileUrl.absoluteString).outputToLog(schemaLog)
            return nil
        }
    }
}
