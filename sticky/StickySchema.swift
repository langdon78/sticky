import Foundation

typealias JSON = Any

internal typealias StickyEntityCollection = [[String: Any]]
internal typealias StickyDataElement = [String: Any]

internal enum SchemaUpdateResult: Equatable {
    case success(StickyDataElement)
    case noAction(StickySchemaAction)
    case error(String)
}

public struct StickySchemaFile {
    public var version: Int
    public var fileUrl: URL
    
    public init(version: Int, fileUrl: URL) {
        self.version = version
        self.fileUrl = fileUrl
    }
}

internal enum StickySchemaAction: CustomStringConvertible, Equatable {
    case renameEntity
    case renameProperty
    case newProperty
    case removeProperty
    
    var description: String {
        switch self {
        case .renameEntity: return "renameEntity"
        case .renameProperty: return "renameProperty"
        case .newProperty: return "newProperty"
        case .removeProperty: return "removeProperty"
        }
    }
    
    func parse(_ data: [String: Any]?, with operation: ([String: Any]) -> SchemaUpdateResult) -> SchemaUpdateResult {
        guard let data = data?[self.description] as? [String: Any] else {
            return .noAction(self)
        }
        return operation(data)
    }
}

public class StickySchemaUpdater {
    
    // MARK: Public properties
    
    public var stickySchemaFile: StickySchemaFile
    public var version: Int {
        return stickySchemaFile.version
    }
    
    // MARK: Private properties
    
    private let actions: [StickySchemaAction] = [
        .renameEntity,
        .renameProperty,
        .newProperty,
        .removeProperty
    ]
    
    private var schemaFileData: Data? {
        do {
            return try Data(contentsOf: stickySchemaFile.fileUrl)
        }
        catch {
            stickyLog("ERROR: Unable to process schema file \(stickySchemaFile.fileUrl)", logAction: .error)
        }
        return nil
    }
    
    private var json: JSON? {
        guard let schemaFileData = schemaFileData else { return nil }
        do {
            return try JSONSerialization.jsonObject(with: schemaFileData, options: [])
        }
        catch {
            stickyLog("ERROR: Unable to parse schema file \(stickySchemaFile.fileUrl)", logAction: .error)
        }
        return nil
    }
    
    private var schemaUpdateData: [String: Any]? {
        guard let dict = json as? [String: Any] else {
            stickyLog("ERROR: Can not parse JSON file", logAction: .error)
            return nil
        }
        return dict
    }
    
    public init(for stickySchemaFile: StickySchemaFile) {
        self.stickySchemaFile = stickySchemaFile
    }
}

// MARK: Public API

extension StickySchemaUpdater {
    
    public static func processUpdates(for schemaFiles: [StickySchemaFile]) {
        // Sort each file by version number then process updates
        schemaFiles
            .sorted { $0.version < $1.version }
            .compactMap { schemaFile in
                StickySchemaUpdater(for: schemaFile)
            }
            .forEach { stickySchema in
                stickySchema.process()
        }
    }
    
    public static func checkUpdateNeeded(for version: Int) -> Bool {
        return version != Sticky.shared.currentSchemaVersion
    }
}

// MARK: Process flow control methods

extension StickySchemaUpdater {
    private func process() {
        for result in processResults(for: schemaUpdateData) {
            if case .error(let error) = result {
                stickyLog("ERROR: Unable to finish schema udpate \(version) due to \(error)", logAction: .error)
                return
            }
        }
        increment(to: version)
    }
    
    private func processResults(for schemaUpdateData: [String: Any]?) -> [SchemaUpdateResult] {
        return actions.map { action in
            action.parse(schemaUpdateData, with: processUpdateMethod(for: action))
        }
    }
    
    private func processUpdateMethod(for action: StickySchemaAction) -> ([String: Any]) -> SchemaUpdateResult {
        switch action {
        case .renameEntity: return processRenameEntity
        case .newProperty: return processNewProperty
        case .renameProperty: return processRenameProperty
        case .removeProperty: return processRemoveProperty
        }
    }
    
    private func increment(to version: Int) {
        Sticky.shared.changeSchemaVersion(to: version)
    }
    
    func applyAction(_ schema: [String: Any], with stored: [String: Any], apply action: StickySchemaAction) -> SchemaUpdateResult {
        var result = stored
        // Loop through properties for update action on entity
        for schemaProperty in schema {
            if let storedProperty = stored[schemaProperty.key] as? [String: Any] {
                if let nestedSchemaProperty = schemaProperty.value as? [String: Any] {
                    _ = applyAction(nestedSchemaProperty, with: storedProperty, apply: action)
                } else {
                    // No nested property in schema
                    switch action {
                    case .renameProperty:
                        if let newName = schemaProperty.value as? String {
                            result.removeValue(forKey: schemaProperty.key)
                            result.updateValue(newName, forKey: schemaProperty.key)
                            return .success(result)
                        } else {
                            return .error("Could not rename property")
                        }
                    case .removeProperty:
                        if let removeList = schemaProperty.value as? [String] {
                            for itemToRemove in removeList {
                                if result.removeValue(forKey: itemToRemove) == nil {
                                    return .error("Property to remove does not exist")
                                }
                            }
                            return .success(result)
                        }
                    default:
                        return .error("Could not apply update")
                    }
                }
            } else {
                // Property doesn't exist in stored
                if action == .newProperty {
                    result.updateValue(schemaProperty.value, forKey: schemaProperty.key)
                    return .success(result)
                } else {
                    return .error("No new property available")
                }
            }
        }
    }
}

// MARK: Process action methods

extension StickySchemaUpdater {
    private func processRenameEntity(for data: [String: Any]) -> SchemaUpdateResult {
        if let renameEntityData = data as? [String: String] {
            // Rename each sticky file listed in schema file
            for (oldName, newName) in renameEntityData {
                let fileResult = FileHandler.renameFile(from: oldName, to: newName)
                switch fileResult {
                case .success:
                    stickyLog("Entity changed from \(oldName) to \(newName)")
                case .error(let error):
                    return .error(error.localizedDescription)
                }
            }
        } else {
            return .error("\"renameEntity\" data contains invalid type")
        }
        return .success
    }
    
    private func processRenameProperty(for data: [String: Any]) -> SchemaUpdateResult {
        let resultMap: [SchemaUpdateResult] = data.map { entity in
            if let properties = entity.value as? [String: String] {
                for (oldName, newName) in properties {
                    return renameProperty(for: entity.key, from: oldName, to: newName)
                }
            }
            return .error("Unable to process file")
        }
        return resultMap.first(where: {$0 != .success}) ?? .success
    }
    
    private func processNewProperty(for data: [String: Any]) -> SchemaUpdateResult {
        let resultMap: [SchemaUpdateResult] = data.map { entity in
            if let properties = entity.value as? [String: Any] {
                for (name, defaultValue) in properties {
                    return addProperty(name, for: entity.key, with: defaultValue)
                }
            }
            return .error("Unable to process file for \(data)")
        }
        return resultMap.first(where: {$0 != .success}) ?? .success
    }
    
    private func processRemoveProperty(for data: [String: Any]) -> SchemaUpdateResult {
        let resultMap: [SchemaUpdateResult] = data.map { entity in
            if let properties = entity.value as? [String] {
                for propertyToRemove in properties {
                    return removeProperty(propertyToRemove, from: entity.key)
                }
            }
            return .error("Unable to process file")
        }
        return resultMap.first(where: {$0 != .success}) ?? .success
    }
}

// MARK: Process action helper methods

extension StickySchemaUpdater {
    
    private func renameProperty(for entityName: String, from oldName: String, to newName: String) -> SchemaUpdateResult {
        guard let storedEntities = readStickyJsonFile(for: entityName) else { return .error("Unable to parse") }
        
        var result: StickyEntityCollection = []
        for var item in storedEntities {
            if let property = item[oldName] {
                item.removeValue(forKey: oldName)
                item.updateValue(property, forKey: newName)
                stickyLog("Changed \(entityName) property name from \"\(oldName)\" to \"\(newName)\"")
            } else {
                return .error("ERROR: Couldn't rename \"\(oldName)\" in \"\(entityName)\" because property doesn't exist.")
            }
            result.append(item)
        }
        
        return writeJsonFile(for: result, to: entityName)
    }
    
    private func addProperty(_ newPropertyName: String, for entityName: String, with defaultValue: Any) -> SchemaUpdateResult {
        guard let storedEntities = readStickyJsonFile(for: entityName) else { return .error("Unable to parse") }
        
        var result: StickyEntityCollection = []
        for var item in storedEntities {
            // Do nothing if property already exists
            if let _ = item[newPropertyName] {
                return .error("ERROR: Couldn't add \"\(newPropertyName)\" to \"\(entityName)\" because property already exists")
            } else {
                item.updateValue(defaultValue, forKey: newPropertyName)
                result.append(item)
                stickyLog("Added property \"\(newPropertyName)\" to \(entityName) with default value of \"\(defaultValue)\"")
            }
        }
        
        return writeJsonFile(for: result, to: entityName)
    }
    
    private func removeProperty(_ removedProperty: String, from entityName: String) -> SchemaUpdateResult {
        guard let storedEntities = readStickyJsonFile(for: entityName) else { return .error("Unable to parse") }
        
        var result: StickyEntityCollection = []
        for var item in storedEntities {
            if let _ = item[removedProperty] {
                item.removeValue(forKey: removedProperty)
                stickyLog("Removed property \"\(removedProperty)\" from \"\(entityName)\"")
            } else {
                return .error("Couldn't remove \"\(removedProperty)\" in \"\(entityName)\" because property doesn't exist.")
            }
            result.append(item)
        }
        return writeJsonFile(for: result, to: entityName)
    }
}

// MARK: File access methods

extension StickySchemaUpdater {
    
    private func readStickyJsonFile(for entityName: String) -> StickyEntityCollection? {
        let filePath = FileHandler.url(for: entityName).path
        guard let data = FileHandler.read(from: filePath) else {
            stickyLog("ERROR: Could not read JSON file data for \(filePath)", logAction: .error)
            return nil
        }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let result = json as? StickyEntityCollection else {
                stickyLog("ERROR: Can not parse JSON file \(filePath)", logAction: .error)
                return nil
            }
            return result
        }
        catch {
            stickyLog(error.localizedDescription)
        }
        return nil
    }
    
    private func writeJsonFile(for entityCollection: StickyEntityCollection, to entityName: String) -> SchemaUpdateResult {
        let filePath = FileHandler.url(for: entityName).path
        do {
            let newData = try JSONSerialization.data(withJSONObject: entityCollection, options: [])
            let fileResult = FileHandler.write(data: newData, to: filePath)
            switch fileResult {
            case .success: return .success
            case .error(let error): return .error(error.localizedDescription)
            }
        }
        catch {
            return .error(error.localizedDescription)
        }
    }
    

}
