import Foundation

internal typealias StickyEntityCollection = [[String: Any]]

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
        if let entityUpdate = dict["renameEntity"] as? [String: String] {
            for (oldName, newName) in entityUpdate {
                if !FileHandler.renameFile(from: oldName, to: newName) {
                    return
                }
            }
        }
        
        // Update property name
        if let propertyUpdate = dict["renameProperty"] as? [String: Any] {
            for entity in propertyUpdate {
                if let properties = entity.value as? [String: String] {
                    for (oldName, newName) in properties {
                        if !renameProperty(for: entity.key, from: oldName, to: newName) { return }
                        print("Changed \(entity.key) property name from \"\(oldName)\" to \"\(newName)\"")
                    }
                }
            }
        }
        
        // Add new property
        if let newProperty = dict["newProperty"] as? [String: Any] {
            for entity in newProperty {
                if let properties = entity.value as? [String: String] {
                    for (name, defaultValue) in properties {
                        if !addProperty(name, for: entity.key, with: defaultValue) { return }
                        print("Added property \"\(name)\" to \(entity.key) with default value of \"\(defaultValue)\"")
                    }
                }
            }
        }
        
        // Remove property
        if let removedProperty = dict["removeProperty"] as? [String: Any] {
            for entity in removedProperty {
                if let properties = entity.value as? [String] {
                    for propertyToRemove in properties {
                        if !removeProperty(propertyToRemove, from: entity.key) { return }
                        print("Removed property \"\(propertyToRemove)\" from \"\(entity.key)\"")
                    }
                }
            }
        }
        Sticky.shared.incrementSchemaVersion(to: version)
    }
    
    public func renameProperty(for entityName: String, from oldName: String, to newName: String) -> Bool {
        guard let storedEntities = readStickyJsonFile(for: entityName) else { return false }
        
        var result: StickyEntityCollection = []
        for var item in storedEntities {
            // Break if property doesn't exist
            if let property = item[oldName] {
                item.removeValue(forKey: oldName)
                item.updateValue(property, forKey: newName)
            } else {
                stickyLog("ERROR: Couldn't rename \"\(oldName)\" in \"\(entityName)\" because property doesn't exist.")
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
                stickyLog("ERROR: Couldn't add \"\(newPropertyName)\" to \"\(entityName)\" because property already exists")
                return false
            } else {
                item.updateValue(defaultValue, forKey: newPropertyName)
                result.append(item)
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
            } else {
                stickyLog("ERROR: Couldn't remove \"\(removedProperty)\" in \"\(entityName)\" because property doesn't exist.")
                return false
            }
            result.append(item)
        }
        return writeJsonFile(for: result, to: entityName)
    }
    
    private func readStickyJsonFile(for entityName: String) -> StickyEntityCollection? {
        let filePath = FileHandler.url(for: entityName).path
        guard let data = FileHandler.read(from: filePath) else {
            stickyLog("ERROR: Could not read JSON file data for \(filePath)")
            return nil
        }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let result = json as? StickyEntityCollection else {
                stickyLog("ERROR: Can not parse JSON file \(filePath)")
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
            stickyLog(error.localizedDescription)
            return false
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
