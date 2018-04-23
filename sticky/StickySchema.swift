import Foundation

typealias JSON = Any

internal typealias StickyEntityCollection = [[String: Any]]
internal typealias StickyDataNode = [String: Any]
internal typealias StickyEntity = String

internal enum SchemaUpdateResult<StickyDataElement> {
    case success(StickyDataElement)
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

internal struct StickySchemaData {
    var action: StickySchemaAction
    var entity: StickyEntity
    var element: StickyDataNode
}

internal enum StickySchemaAction: String {
    case renameEntity
    case renameProperty
    case newProperty
    case removeProperty
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
        stickyLog("----Begin update to version \(version)----")
        stickyLog("Processing schema file...")
        guard let data = processUpdaterResult(schemaData(from: stickySchemaFile)) else { return }
        
        stickyLog("Converting data file to json...")
        guard let jsonData = processUpdaterResult(json(from: data)) else { return }
        
        stickyLog("Converting json to dictionary...")
        guard let dictionaryData = processUpdaterResult(dictionary(from: jsonData)) else { return }
        
        stickyLog("Looking for actions to process...")
        guard let schemaData = processUpdaterResult(stickySchemaData(for: dictionaryData)) else { return }
        
        stickyLog("----Processing actions...")
        for schemaUpdateAction in schemaData {
            stickyLog("----Processing \(schemaUpdateAction.action.rawValue) for \(schemaUpdateAction.entity)----")
            if schemaUpdateAction.action == .renameEntity {
                guard let _ = processUpdaterResult(processRenameEntity(for: schemaUpdateAction.element)) else { return }
                continue
            }
            var result: StickyEntityCollection = []
            guard let stored = readStickyJsonFile(for: schemaUpdateAction.entity) else { return }
            for  element in stored {
                guard let processedElement = processUpdaterResult(applyAction(schemaUpdateAction.element, with: element, apply: schemaUpdateAction.action)) else { return }
                result.append(processedElement)
            }
            let writeResult = writeJsonFile(for: result, to: schemaUpdateAction.entity)
            if case .error(_) = writeResult {
                return
            }
        }
        
        increment(to: version)
    }
    
    func processUpdaterResult<T>(_ result: SchemaUpdateResult<T>) -> T? {
        switch result {
        case .success(let data):
            stickyLog("Success")
            return data
        case .error(let error):
            stickyLog("ERROR: \(error)", logAction: .error)
            return nil
        }
    }
    
    private func stickySchemaData(for stickyDataNode: StickyDataNode) -> SchemaUpdateResult<[StickySchemaData]> {
        var stickySchemaData: [StickySchemaData] = []
        for (actionName, entityData) in stickyDataNode {
            if let action = StickySchemaAction(rawValue: actionName) {
                if let entity = entityData as? StickyDataNode {
                    for (entityName, propertyData) in entity {
                        if let properties = propertyData as? StickyDataNode {
                            stickySchemaData.append(StickySchemaData(action: action, entity: entityName, element: properties))
                        } else if action == .renameEntity {
                            stickySchemaData.append(StickySchemaData(action: action, entity: entityName, element: entity))
                        } else {
                            return .error("Properties for action \"\(actionName)\" and entity \"\(entityName)\" are malformed")
                        }
                    }
                } else {
                    return .error("Entity data for action \"\(actionName)\" is malformed")
                }
            } else {
                return .error("\"\(actionName)\" doesn't match any available actions")
            }
        }
        return .success(stickySchemaData)
    }
    
//    private func processUpdateMethod(for action: StickySchemaAction) -> ([String: Any]) -> SchemaUpdateResult {
//        switch action {
//        case .renameEntity: return processRenameEntity
//        case .newProperty: return processNewProperty
//        case .renameProperty: return processRenameProperty
//        case .removeProperty: return processRemoveProperty
//        }
//    }
    
    private func increment(to version: Int) {
        Sticky.shared.changeSchemaVersion(to: version)
    }
    
    private func schemaData(from file: StickySchemaFile) -> SchemaUpdateResult<Data> {
        do {
            let data = try Data(contentsOf: file.fileUrl)
            return .success(data)
        }
        catch {
            return .error("Unable to process schema file \(file.fileUrl)")
        }
    }
    
    private func json(from data: Data) -> SchemaUpdateResult<JSON> {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return .success(json)
        }
        catch {
            return .error("Unable to parse json for \(stickySchemaFile.fileUrl)")
        }
    }
    
    private func dictionary(from json: JSON) -> SchemaUpdateResult<StickyDataNode> {
        guard let dict = json as? StickyDataNode else {
            return .error("Can not parse JSON file")
        }
        return .success(dict)
    }
    
    func applyAction(_ schema: StickyDataNode, with stored: StickyDataNode, apply action: StickySchemaAction) -> SchemaUpdateResult<StickyDataNode> {
        var result = stored
        // Loop through properties for update action on entity
        for schemaProperty in schema {
            if let storedProperty = stored[schemaProperty.key] {
                if let nestedSchemaProperty = schemaProperty.value as? StickyDataNode, let storedProperty = storedProperty as? StickyDataNode {
                    _ = applyAction(nestedSchemaProperty, with: storedProperty, apply: action)
                } else {
                    // No nested property in schema
                    switch action {
                    case .renameProperty:
                        if let newName = schemaProperty.value as? String, let property = stored[schemaProperty.key] {
                            result.removeValue(forKey: schemaProperty.key)
                            result.updateValue(property, forKey: newName)
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
        return .success(result)
    }
}

// MARK: Process action methods

extension StickySchemaUpdater {
    private func processRenameEntity(for data: [String: Any]) -> SchemaUpdateResult<Bool> {
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
        return .success(true)
    }
//
//    private func processRenameProperty(for data: [String: Any]) -> SchemaUpdateResult {
//        let resultMap: [SchemaUpdateResult] = data.map { entity in
//            if let properties = entity.value as? [String: String] {
//                for (oldName, newName) in properties {
//                    return renameProperty(for: entity.key, from: oldName, to: newName)
//                }
//            }
//            return .error("Unable to process file")
//        }
//        return resultMap.first(where: {$0 != .success}) ?? .success
//    }
//
//    private func processNewProperty(for data: [String: Any]) -> SchemaUpdateResult {
//        let resultMap: [SchemaUpdateResult] = data.map { entity in
//            if let properties = entity.value as? [String: Any] {
//                for (name, defaultValue) in properties {
//                    return addProperty(name, for: entity.key, with: defaultValue)
//                }
//            }
//            return .error("Unable to process file for \(data)")
//        }
//        return resultMap.first(where: {$0 != .success}) ?? .success
//    }
//
//    private func processRemoveProperty(for data: [String: Any]) -> SchemaUpdateResult {
//        let resultMap: [SchemaUpdateResult] = data.map { entity in
//            if let properties = entity.value as? [String] {
//                for propertyToRemove in properties {
//                    return removeProperty(propertyToRemove, from: entity.key)
//                }
//            }
//            return .error("Unable to process file")
//        }
//        return resultMap.first(where: {$0 != .success}) ?? .success
//    }
}

// MARK: Process action helper methods

//extension StickySchemaUpdater {
//
//    private func renameProperty(for entityName: String, from oldName: String, to newName: String) -> SchemaUpdateResult {
//        guard let storedEntities = readStickyJsonFile(for: entityName) else { return .error("Unable to parse") }
//
//        var result: StickyEntityCollection = []
//        for var item in storedEntities {
//            if let property = item[oldName] {
//                item.removeValue(forKey: oldName)
//                item.updateValue(property, forKey: newName)
//                stickyLog("Changed \(entityName) property name from \"\(oldName)\" to \"\(newName)\"")
//            } else {
//                return .error("ERROR: Couldn't rename \"\(oldName)\" in \"\(entityName)\" because property doesn't exist.")
//            }
//            result.append(item)
//        }
//
//        return writeJsonFile(for: result, to: entityName)
//    }
//
//    private func addProperty(_ newPropertyName: String, for entityName: String, with defaultValue: Any) -> SchemaUpdateResult {
//        guard let storedEntities = readStickyJsonFile(for: entityName) else { return .error("Unable to parse") }
//
//        var result: StickyEntityCollection = []
//        for var item in storedEntities {
//            // Do nothing if property already exists
//            if let _ = item[newPropertyName] {
//                return .error("ERROR: Couldn't add \"\(newPropertyName)\" to \"\(entityName)\" because property already exists")
//            } else {
//                item.updateValue(defaultValue, forKey: newPropertyName)
//                result.append(item)
//                stickyLog("Added property \"\(newPropertyName)\" to \(entityName) with default value of \"\(defaultValue)\"")
//            }
//        }
//
//        return writeJsonFile(for: result, to: entityName)
//    }
//
//    private func removeProperty(_ removedProperty: String, from entityName: String) -> SchemaUpdateResult {
//        guard let storedEntities = readStickyJsonFile(for: entityName) else { return .error("Unable to parse") }
//
//        var result: StickyEntityCollection = []
//        for var item in storedEntities {
//            if let _ = item[removedProperty] {
//                item.removeValue(forKey: removedProperty)
//                stickyLog("Removed property \"\(removedProperty)\" from \"\(entityName)\"")
//            } else {
//                return .error("Couldn't remove \"\(removedProperty)\" in \"\(entityName)\" because property doesn't exist.")
//            }
//            result.append(item)
//        }
//        return writeJsonFile(for: result, to: entityName)
//    }
//}

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
    
    private func writeJsonFile(for entityCollection: StickyEntityCollection, to entityName: String) -> SchemaUpdateResult<Bool> {
        let filePath = FileHandler.url(for: entityName).path
        do {
            let newData = try JSONSerialization.data(withJSONObject: entityCollection, options: [])
            let fileResult = FileHandler.write(data: newData, to: filePath)
            switch fileResult {
            case .success: return .success(true)
            case .error(let error): return .error(error.localizedDescription)
            }
        }
        catch {
            return .error(error.localizedDescription)
        }
    }
    

}
