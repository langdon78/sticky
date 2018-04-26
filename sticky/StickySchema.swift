import Foundation

typealias JSON = Any

internal typealias StickyEntityCollection<Key: Hashable> = [[Key: Any]]
internal typealias StickyDataMap<Key: Hashable> = [Key: Any]
internal typealias StickyEntity = String

internal enum SchemaUpdateResult: Equatable {
    case success
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

internal struct StickySchemaData<Key: Hashable> {
    var action: StickySchemaAction<Key>
    var entity: StickyEntity
    var node: Node<Key>
}

struct Node<Key: Hashable> {
    var path: [Key]
    var key: Key
    var value: Any
}

internal enum StickySchemaAction<Key: Hashable>: String {
    case renameEntity
    case renameProperty
    case newProperty
    case removeProperty
    
    init?(_ value: Key) {
        guard
            let stringValue = value as? String,
            let action = StickySchemaAction(rawValue: stringValue)
            else { return nil }
        self =  action
    }
}

public class StickySchemaUpdater {
    
    // MARK: Public properties
    
    public var stickySchemaFile: StickySchemaFile
    public var version: Int {
        return stickySchemaFile.version
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
        stickyLog("----Begin update to version \(version)----")
        stickyLog("Processing schema file...")
        guard let data = schemaData(from: stickySchemaFile) else { return }
        
        stickyLog("Converting data file to json...")
        guard let jsonData = json(from: data) else { return }
        
        stickyLog("Converting json to dictionary...")
        guard let dictionaryData = dictionary(from: jsonData) else { return }
        
        stickyLog("Looking for actions to process...")
        guard let schemaActionItems = parseSchema(from: dictionaryData) else { return }
        
        var memoryStore: [StickyEntity: StickyEntityCollection<String>] = [:]

        stickyLog("Processing actions...")
        
        for actionItem in schemaActionItems {
            guard var stored = stored(for: actionItem.entity, memoryStore: memoryStore) else { return }
            
            stickyLog("Processing \"\(actionItem.action.rawValue)\"", logAction: .info)
            if processSchemaAction(for: actionItem, on: &stored) != .success {
                return
            }
            
            // No new data needs to be written after file renaming
            if actionItem.action != .renameEntity {
                memoryStore.updateValue(stored, forKey: actionItem.entity)
            }
            stored = []
        }
        
        // Write data to file
        for (entity, stored) in memoryStore {
            let writeResult = writeJsonFile(for: stored, to: entity)
            if case .error(_) = writeResult {
                return
            }
        }
        
        stickyLog("Successfully updated Sticky schema to version \(version)", logAction: .info)
        increment(to: version)
        stickyLog("----End update----")
    }
    
    private func processSchemaAction<Key: Hashable>(for data: StickySchemaData<Key>, on collection: inout StickyEntityCollection<Key>) -> SchemaUpdateResult {
        if data.action == .renameEntity,
            let oldName = data.node.key as? String,
            let newName = data.node.value as? String {
            if case let .error(error) = processRenameEntity(from: oldName, to: newName) {
                stickyLog(error, logAction: .error)
                return .error(error)
            }
            return .success
        }
        
        var resultCollection: StickyEntityCollection<Key> = []
        for dataItem in collection {
            stickyLog("Performing action \(data.action) on entity \(data.entity)")
            let action = data.action
            switch action {
            case .removeProperty:
                stickyLog("Removing property \"\(data.node.value)\" for \"\(data.entity)\"", logAction: .info)
                if let properties = data.node.value as? [Key] {
                    var pathWithKey = data.node.path
                    pathWithKey.append(data.node.key)
                    let updatedItem = performOperation(on: dataItem, at: pathWithKey, with: removeKeys(properties))
                    resultCollection.append(updatedItem)
                }
            case .newProperty:
                stickyLog("Adding new property \"\(data.node.key)\" with default value \"\(data.node.value)\" to \"\(data.entity)\"", logAction: .info)
                let updatedItem = performOperation(on: dataItem, at: data.node.path, with: newNode(data.node.value, for: data.node.key), overwrite: true)
                resultCollection.append(updatedItem)
            case .renameProperty:
                stickyLog("Renaming property \"\(data.node.key)\" to \"\(data.node.value)\" for \"\(data.entity)\"", logAction: .info)
                let oldKey = data.node.key
                if let newKey = data.node.value as? Key {
                    let updatedItem = performOperation(on: dataItem, at: data.node.path, with: renameKey(from: oldKey, to: newKey))
                    resultCollection.append(updatedItem)
                }
            default:
                stickyLog("No action taken")
            }
        }
        collection = resultCollection
        stickyLog("Success", logAction: .info)
        return .success
    }
    
    private func collectionFromMemory<Key: Hashable>(for entity: StickyEntity, from dataStore: [StickyEntity: StickyEntityCollection<Key>]) -> StickyEntityCollection<Key>? {
        return dataStore[entity]
    }
    
    private func collectionFromDisk<Key: Hashable>(for entity: StickyEntity) -> StickyEntityCollection<Key>? {
        return readStickyJsonFile(for: entity)
    }
    
    private func stored<Key: Hashable>(for entity: StickyEntity, memoryStore: [StickyEntity: StickyEntityCollection<Key>]) -> StickyEntityCollection<Key>? {
        if let memory = collectionFromMemory(for: entity, from: memoryStore) {
            return memory
        } else if let disk: StickyEntityCollection<Key> = collectionFromDisk(for: entity) {
            return disk
        } else {
            stickyLog("Data file for \"\(entity)\" does not exist")
            return nil
        }
    }
    
    private func parseSchema<Key: Hashable>(from schema: StickyDataMap<Key>) -> [StickySchemaData<Key>]? {
        let nodes = parseKeys(for: schema, nodes: [], path: [])
        var returnSchemaData: [StickySchemaData<Key>] = []
        for node in nodes {
            guard let schemaData = schemaData(for: node) else { return nil }
            returnSchemaData.append(schemaData)
        }
        return returnSchemaData
    }
    
    private func schemaData<Key: Hashable>(for node: Node<Key>) -> StickySchemaData<Key>? {
        var path = node.path
        
        guard let actionName = parseFirst(from: &path) else {
                stickyLog("Malformed or empty schema file", logAction: .error)
                return nil
        }
        
        guard let action = StickySchemaAction(actionName) else {
                stickyLog("Invalid action \"\(actionName)\"", logAction: .error)
                return nil
        }
        
        guard let entityName = entityName(for: action, nodeKey: node.key, path: &path) else {
            stickyLog("Unable to parse entity name for action \"\(action.rawValue)\"")
            return nil
        }
        
        let returnNode = Node(path: path, key: node.key, value: node.value)
        return StickySchemaData(action: action, entity: entityName, node: returnNode)
    }
    
    private func entityName<Key: Hashable>(for action: StickySchemaAction<Key>, nodeKey: Key, path: inout [Key]) -> String? {
        // If path is empty, assign key to entityName
        if path.isEmpty, let keyEntityName = nodeKey as? String {
            return keyEntityName
        } else if let pathEntityName = parseFirst(from: &path) as? String {
            return pathEntityName
        } else {
            return nil
        }
    }
    
    private func parseFirst<Key: Hashable>(from list: inout [Key]) -> Key? {
        guard !list.isEmpty else { return nil }
        return list.removeFirst()
    }
    
    private func increment(to version: Int) {
        Sticky.shared.changeSchemaVersion(to: version)
    }
    
    private func schemaData(from file: StickySchemaFile) -> Data? {
        do {
            let data = try Data(contentsOf: file.fileUrl)
            return data
        }
        catch {
            stickyLog("Unable to process schema file \(file.fileUrl)", logAction: .error)
            return nil
        }
    }
    
    private func json(from data: Data) -> JSON? {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json
        }
        catch {
            stickyLog("Unable to parse json for \(stickySchemaFile.fileUrl)", logAction: .error)
            return nil
        }
    }
    
    private func dictionary(from json: JSON) -> StickyDataMap<String>? {
        guard let dict = json as? [String: Any] else {
            stickyLog("Can not parse JSON file", logAction: .error)
            return nil
        }
        return dict
    }
    
    // Method to parse schema properties returning all key/values
    // with respective paths. Output will be used later to traverse
    // stored json files and perform change operations
    func parseKeys<Key: Hashable>(for dict: [Key: Any], nodes: [Node<Key>], path: [Key]) -> [Node<Key>] {
        let availableKeys = Array(dict.keys)
        var result = nodes
        var path = path
        
        for key in availableKeys {
            if let childNode = dict[key] {
                // Drop invalid keys from path
                if let last = path.last, dict[last] != nil {
                    _ = path.popLast()
                }
                // Check if children are nodes
                if let parseable = childNode as? [Key: Any] {
                    // add key to path and recurse
                    path.append(key)
                    result = parseKeys(for: parseable, nodes: result, path: path)
                } else {
                    // create result node from key/value and path
                    result.append(Node(path: path, key: key, value: childNode))
                }
            }
        }
        return result
    }
    
    // Takes a dictionary, keypath (array), and operation
    // Searches dictionary for given keypath, then performs operation
    // on that node, returning an updated node to replace existing.
    // Will be used to update Sticky json files as
    // data "schema" changes are required
    func performOperation<Key: Hashable>(on dictionary: [Key: Any], at path: [Key], with operation: ([Key: Any]) -> [Key: Any], overwrite: Bool = false) -> [Key: Any] {
        var result = dictionary
        
        if path.isEmpty { return operation(result) }
        
        var queue: [[Key: Any]] = []
        queue.append(result)
        
        // Traverse dictionary path and perform operation on node
        for key in path {
            if var currentNode = queue.last {
                // If path doesn't exist create node
                // Used primarily for adding new nested nodes
                if overwrite, currentNode[key] == nil {
                    currentNode.updateValue([:], forKey: key)
                }
                // If valid child node, perform operation and update result queue
                if let nestedNode = currentNode[key] as? [Key: Any] {
                    let updatedNode = operation(nestedNode)
                    queue.append(updatedNode)
                }
            }
        }
        
        // Build up result dictionary with updated values
        if var last = queue.popLast() {
            for key in path.reversed() {
                if var node = queue.popLast() {
                    node.updateValue(last, forKey: key)
                    last = node
                }
            }
            result = last
        }
        
        return result
    }
    
    func renameKey<Key: Hashable>(from oldKey: Key, to newKey: Key) -> ([Key: Any]) -> [Key: Any] {
        return { dict in
            var result = dict
            if let value = dict[oldKey] {
                result.removeValue(forKey: oldKey)
                result.updateValue(value, forKey: newKey)
            }
            return result
        }
    }
    
    func removeKeys<Key: Hashable>(_ keys: [Key]) -> ([Key: Any]) -> [Key: Any] {
        return { dict in
            var result = dict
            for key in keys {
                result.removeValue(forKey: key)
            }
            return result
        }
    }
    
    func newNode<Key: Hashable>(_ node: Any, for key: Key) -> ([Key: Any]) -> [Key: Any] {
        return { dict in
            var result = dict
            result.updateValue(node, forKey: key)
            return result
        }
    }
}

// MARK: Process action methods

extension StickySchemaUpdater {
    private func processRenameEntity(from oldName: String, to newName: String) -> SchemaUpdateResult {
        let fileResult = FileHandler.renameFile(from: oldName, to: newName)
        switch fileResult {
        case .success:
            stickyLog("Entity changed from \(oldName) to \(newName)")
        case .error(let error):
            return .error(error.localizedDescription)
        }
        return .success
    }
}

// MARK: File access methods

extension StickySchemaUpdater {
    
    private func readStickyJsonFile<Key: Hashable>(for entityName: String) -> StickyEntityCollection<Key>? {
        let filePath = FileHandler.url(for: entityName).path
        guard let data = FileHandler.read(from: filePath) else {
            stickyLog("ERROR: Could not read JSON file data for \(filePath)", logAction: .error)
            return nil
        }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let result = json as? StickyEntityCollection<Key> else {
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
    
    private func writeJsonFile(for entityCollection: StickyEntityCollection<String>, to entityName: String) -> SchemaUpdateResult {
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
