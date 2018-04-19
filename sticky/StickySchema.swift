import Foundation

typealias JSON = Any

internal typealias StickyEntityCollection = [[String: Any]]

public struct StickySchemaFile {
    public var version: Int
    public var fileUrl: URL
    
    public init(version: Int, fileUrl: URL) {
        self.version = version
        self.fileUrl = fileUrl
    }
}

fileprivate enum StickySchemaAction: CustomStringConvertible {
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
    
    func parse(_ data: [String: Any]?, with operation: ([String: Any]) -> Bool) -> Bool {
        guard let data = data?[self.description] as? [String: Any] else {
            stickyLog("No required action for \(description)")
            return false
        }
        return operation(data)
    }
}

public class StickySchema {
    public var stickySchemaFile: StickySchemaFile
    
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
    
    private var schemaActionData: [String: Any]? {
        guard let dict = json as? [String: Any] else {
            stickyLog("ERROR: Can not parse JSON file", logAction: .error)
            return nil
        }
        return dict
    }
    
    public var version: Int {
        return stickySchemaFile.version
    }
    
    init(for stickySchemaFile: StickySchemaFile) {
        self.stickySchemaFile = stickySchemaFile
    }
    
    public func process() {
        
        guard StickySchemaAction.renameEntity.parse(schemaActionData, with: processRenameEntity) else { return }
        guard StickySchemaAction.renameProperty.parse(schemaActionData, with: processRenameProperty) else { return }
        guard StickySchemaAction.newProperty.parse(schemaActionData, with: processNewProperty) else { return }
        guard StickySchemaAction.removeProperty.parse(schemaActionData, with: processRemoveProperty) else { return }
        Sticky.shared.incrementSchemaVersion(to: version)
    }
    
    private func processRenameEntity(for data: [String: Any]) -> Bool {
        if let renameEntityData = data as? [String: String] {
            let resultMap = renameEntityData.map { (oldName, newName) in
                FileHandler.renameFile(from: oldName, to: newName)
            }
            return !resultMap.contains(false)
        }
        return false
    }
    
    private func processRenameProperty(for data: [String: Any]) -> Bool {
        let resultMap: [Bool] = data.map { entity in
            if let properties = entity.value as? [String: String] {
                for (oldName, newName) in properties {
                    return renameProperty(for: entity.key, from: oldName, to: newName)
                }
            }
            return false
        }
        return !resultMap.contains(false)
    }
    
    private func processNewProperty(for data: [String: Any]) -> Bool {
        let resultMap: [Bool] = data.map { entity in
            if let properties = entity.value as? [String: String] {
                for (name, defaultValue) in properties {
                    return addProperty(name, for: entity.key, with: defaultValue)
                    
                }
            }
            return false
        }
        return !resultMap.contains(false)
    }
    
    private func processRemoveProperty(for data: [String: Any]) -> Bool {
        let resultMap: [Bool] = data.map { entity in
            if let properties = entity.value as? [String] {
                for propertyToRemove in properties {
                    return removeProperty(propertyToRemove, from: entity.key)
                }
            }
            return false
        }
        return !resultMap.contains(false)
    }
    
    public func renameProperty(for entityName: String, from oldName: String, to newName: String) -> Bool {
        guard let storedEntities = readStickyJsonFile(for: entityName) else { return false }
        
        var result: StickyEntityCollection = []
        for var item in storedEntities {
            if let property = item[oldName] {
                item.removeValue(forKey: oldName)
                item.updateValue(property, forKey: newName)
                stickyLog("Changed \(entityName) property name from \"\(oldName)\" to \"\(newName)\"")
            } else {
                stickyLog("ERROR: Couldn't rename \"\(oldName)\" in \"\(entityName)\" because property doesn't exist.", logAction: .error)
                return false
            }
            result.append(item)
        }
        
        return writeJsonFile(for: result, to: entityName)
    }
    
    public func addProperty(_ newPropertyName: String, for entityName: String, with defaultValue: Any) -> Bool {
        guard let storedEntities = readStickyJsonFile(for: entityName) else { return false }
        
        var result: StickyEntityCollection = []
        for var item in storedEntities {
            // Do nothing if property already exists
            if let _ = item[newPropertyName] {
                stickyLog("ERROR: Couldn't add \"\(newPropertyName)\" to \"\(entityName)\" because property already exists", logAction: .error)
                return false
            } else {
                item.updateValue(defaultValue, forKey: newPropertyName)
                result.append(item)
                stickyLog("Added property \"\(newPropertyName)\" to \(entityName) with default value of \"\(defaultValue)\"")
            }
        }
        
        return writeJsonFile(for: result, to: entityName)
    }
    
    private func removeProperty(_ removedProperty: String, from entityName: String) -> Bool {
        guard let storedEntities = readStickyJsonFile(for: entityName) else { return false }
        
        var result: StickyEntityCollection = []
        for var item in storedEntities {
            if let _ = item[removedProperty] {
                item.removeValue(forKey: removedProperty)
                stickyLog("Removed property \"\(removedProperty)\" from \"\(entityName)\"")
            } else {
                stickyLog("ERROR: Couldn't remove \"\(removedProperty)\" in \"\(entityName)\" because property doesn't exist.", logAction: .error)
                return false
            }
            result.append(item)
        }
        return writeJsonFile(for: result, to: entityName)
    }
    
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
    
    private func writeJsonFile(for entityCollection: StickyEntityCollection, to entityName: String) -> Bool {
        let filePath = FileHandler.url(for: entityName).path
        do {
            let newData = try JSONSerialization.data(withJSONObject: entityCollection, options: [])
            return FileHandler.write(data: newData, to: filePath)
        }
        catch {
            stickyLog(error.localizedDescription, logAction: .error)
            return false
        }
    }
    
    public static func processUpdates(for schemaFiles: [StickySchemaFile]) {
        schemaFiles
        .sorted { $0.version < $1.version }
            .compactMap { schemaFile in
                StickySchema(for: schemaFile)
            }
            .forEach { stickySchema in
                stickySchema.process()
        }
    }
    
    public static func checkUpdateNeeded(for version: Int) -> Bool {
        return version != Sticky.shared.currentSchemaVersion
    }
}
