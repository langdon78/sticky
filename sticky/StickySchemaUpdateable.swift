import Foundation

public protocol StickySchemaUpdateable {
    static var fileVersionMap: [Int: String] { get set }
    static var schemaFileExtension: String { get set }
    static func processUpdates()
}

public extension StickySchemaUpdateable {
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
            .filter { $0.version > Sticky.shared.currentSchemaVersion }
    }
    
    fileprivate static var maxVersion: Int {
        return fileVersionMap
            .sorted { $0.key < $1.key }
            .last?.key ?? 0
    }
    
    static func processUpdates() {
        if StickySchemaUpdater.checkUpdateNeeded(for: maxVersion) {
            StickySchemaUpdater.processUpdates(for: schemaFiles)
        }
    }
}
