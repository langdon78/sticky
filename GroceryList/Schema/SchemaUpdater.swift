import Foundation
import Sticky

struct StoredDataSchemaUpdater: StickySchemaUpdateable {
    static var schemaFileExtension = "json"
    // Set [{version}: {fileName}]
    static var fileVersionMap: [Int: String] = [
        1: "sticky_schema_1",
        2: "sticky_schema_2",
        3: "sticky_schema_3"
    ]
}
