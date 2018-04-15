import Foundation
import Sticky

class StoredDataSchemaUpdater {
    fileprivate static let schemaFileExtension = "json"
    // Set [{version}: {fileName}]
    fileprivate static let fileVersionMap: [Int: String] = [
        1:"sticky_schema_1"
    ]
    
    fileprivate static var schemaFiles: [StickySchemaFile] {
        let bundle = Bundle.main
        return fileVersionMap
            .compactMap { fileVersion in
                guard let url = bundle.url(
                    forResource: fileVersion.value,
                    withExtension: schemaFileExtension
                    ) else { return nil }
                return StickySchemaFile(version: fileVersion.key, fileUrl: url)
        }
    }
    
    fileprivate static var maxVersion: Int {
        return fileVersionMap
            .sorted { $0.key < $1.key }
            .last?.key ?? 0
    }
    
    static func processUpdates() {
        if StickySchema.checkUpdateNeeded(for: maxVersion) {
            StickySchema.processUpdates(for: schemaFiles)
        }
    }
}
