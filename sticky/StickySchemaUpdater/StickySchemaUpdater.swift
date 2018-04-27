import Foundation

// Aliases for stored data
internal typealias StickyStoredEntity<Key: Hashable> = [[Key: Any]]
internal typealias StickyEntityName = String
internal typealias StickyEntityItem<Key: Hashable> = [Key: Any]

// Aliases for schema data
internal typealias StickySchemaMap<Key: Hashable> = [Key: Any]

internal enum SchemaUpdateResult: Equatable {
    case success
    case error(String)
}

internal enum StickySchemaActionType<Key: Hashable>: String {
    case renameEntity
    case renameProperty
    case newProperty
    case removeProperty
    
    init?(_ value: Key) {
        guard
            let stringValue = value as? String,
            let actionType = StickySchemaActionType(rawValue: stringValue)
            else { return nil }
        self =  actionType
    }
}

fileprivate struct StickySchemaAction<Key: Hashable> {
    var actionType: StickySchemaActionType<Key>
    var entityName: StickyEntityName
    var node: Node<Key>
}

fileprivate struct Node<Key: Hashable> {
    var path: [Key]
    var key: Key
    var value: Any
}

internal class StickySchemaUpdater {
    
    var stickySchemaFile: StickySchemaFile
    var version: Int {
        return stickySchemaFile.version
    }
    
    init(for stickySchemaFile: StickySchemaFile) {
        self.stickySchemaFile = stickySchemaFile
    }
}

// MARK: Process Control

extension StickySchemaUpdater {
    
    internal static func processUpdates(for schemaFiles: [StickySchemaFile]) {
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
    
    internal static func checkUpdateNeeded(for version: Int) -> Bool {
        return version != Sticky.shared.currentSchemaVersion
    }
    
    private func increment(to version: Int) {
        Sticky.shared.changeSchemaVersion(to: version)
    }
    
    private func process() {
        var memoryStore: [StickyEntityName: StickyStoredEntity<String>] = [:]
        
        stickyLog("----Begin update to version \(version)----")
        
        stickyLog("Importing schema file...")
        guard let stickySchemaMap = stickySchemaFile.toStickySchemaMap() else { return }

        stickyLog("Looking for actions to process...")
        guard let schemaActions = schemaActions(from: stickySchemaMap) else { return }
        
        stickyLog("Processing actions...")
        
        for action in schemaActions {
            guard var stored = stored(for: action.entityName, memoryStore: memoryStore) else { return }
            
            stickyLog("Processing \"\(action.actionType.rawValue)\"", logAction: .info)
            if processSchemaAction(for: action, on: &stored) != .success {
                return
            }
            
            // Remove old entity from memory store if entity is renamed
            if action.actionType == .renameEntity {
                memoryStore.removeValue(forKey: action.entityName)
            } else {
                memoryStore.updateValue(stored, forKey: action.entityName)
            }
            stored = []
        }
        
        // Write data to file
        for (entity, stored) in memoryStore {
            let writeResult = FileHandler.writeJsonFile(for: stored, to: entity)
            if case .error(_) = writeResult {
                return
            }
        }
        
        stickyLog("Successfully updated Sticky schema to version \(version)", logAction: .info)
        increment(to: version)
        stickyLog("----End update----")
    }
}

// MARK: Schema parsing and update methods

extension StickySchemaUpdater {
    
    private func processSchemaAction<Key: Hashable>(for data: StickySchemaAction<Key>, on storedEntity: inout StickyStoredEntity<Key>) -> SchemaUpdateResult {
        if data.actionType == .renameEntity,
            let oldName = data.node.key as? String,
            let newName = data.node.value as? String {
            if case let .error(error) = renameEntity(from: oldName, to: newName) {
                stickyLog(error, logAction: .error)
                return .error(error)
            }
            return .success
        }
        
        var resultEntity: StickyStoredEntity<Key> = []
        for item in storedEntity {
            stickyLog("Performing action \(data.actionType) on entity \(data.entityName)")
            let action = data.actionType
            switch action {
            case .removeProperty:
                stickyLog("Removing property \"\(data.node.value)\" for \"\(data.entityName)\"", logAction: .info)
                if let properties = data.node.value as? [Key] {
                    var pathWithKey = data.node.path
                    pathWithKey.append(data.node.key)
                    let updatedItem = performOperation(on: item, at: pathWithKey, with: removeKeys(properties))
                    resultEntity.append(updatedItem)
                }
            case .newProperty:
                stickyLog("Adding new property \"\(data.node.key)\" with default value \"\(data.node.value)\" to \"\(data.entityName)\"", logAction: .info)
                let updatedItem = performOperation(on: item, at: data.node.path, with: newNode(data.node.value, for: data.node.key), overwrite: true)
                resultEntity.append(updatedItem)
            case .renameProperty:
                stickyLog("Renaming property \"\(data.node.key)\" to \"\(data.node.value)\" for \"\(data.entityName)\"", logAction: .info)
                let oldKey = data.node.key
                if let newKey = data.node.value as? Key {
                    let updatedItem = performOperation(on: item, at: data.node.path, with: renameKey(from: oldKey, to: newKey))
                    resultEntity.append(updatedItem)
                }
            default:
                stickyLog("No action taken")
            }
        }
        storedEntity = resultEntity
        stickyLog("Success", logAction: .info)
        return .success
    }
    
    private func entityFromMemory<Key: Hashable>(for entityName: StickyEntityName, from dataStore: [StickyEntityName: StickyStoredEntity<Key>]) -> StickyStoredEntity<Key>? {
        return dataStore[entityName]
    }
    
    private func entityFromDisk<Key: Hashable>(for entityName: StickyEntityName) -> StickyStoredEntity<Key>? {
        return FileHandler.readJsonFile(for: entityName)
    }
    
    private func stored<Key: Hashable>(for entity: StickyEntityName, memoryStore: [StickyEntityName: StickyStoredEntity<Key>]) -> StickyStoredEntity<Key>? {
        if let memory = entityFromMemory(for: entity, from: memoryStore) {
            return memory
        } else if let disk: StickyStoredEntity<Key> = entityFromDisk(for: entity) {
            return disk
        } else {
            stickyLog("Data file for \"\(entity)\" does not exist")
            return nil
        }
    }
    
    private func schemaActions<Key: Hashable>(from schema: StickySchemaMap<Key>) -> [StickySchemaAction<Key>]? {
        let nodes = navigationList(for: schema)
        var templateList: [StickySchemaAction<Key>] = []
        for node in nodes {
            guard let template = schemaAction(for: node) else { return nil }
            templateList.append(template)
        }
        return templateList
    }
    
    private func schemaAction<Key: Hashable>(for node: Node<Key>) -> StickySchemaAction<Key>? {
        var path = node.path
        
        guard let actionName = parseFirstKey(from: &path) else {
                stickyLog("Malformed or empty schema file", logAction: .error)
                return nil
        }
        
        guard let actionType = StickySchemaActionType(actionName) else {
                stickyLog("Invalid action \"\(actionName)\"", logAction: .error)
                return nil
        }
        
        guard let entityName = entityName(for: actionType, nodeKey: node.key, path: &path) else {
            stickyLog("Unable to parse entity name for action \"\(actionType.rawValue)\"")
            return nil
        }
        
        let returnNode = Node(path: path, key: node.key, value: node.value)
        return StickySchemaAction(actionType: actionType, entityName: entityName, node: returnNode)
    }
    
    private func entityName<Key: Hashable>(for action: StickySchemaActionType<Key>, nodeKey: Key, path: inout [Key]) -> String? {
        // If path is empty, assign key to entityName
        if path.isEmpty, let keyEntityName = nodeKey as? String {
            return keyEntityName
        } else if let pathEntityName = parseFirstKey(from: &path) as? String {
            return pathEntityName
        } else {
            return nil
        }
    }
    
    private func parseFirstKey<Key: Hashable>(from list: inout [Key]) -> Key? {
        guard !list.isEmpty else { return nil }
        return list.removeFirst()
    }
    
    // Method to parse schema properties returning all key/values
    // with respective paths. Output will be used later to traverse
    // stored json files and perform change operations
    private func navigationList<Key: Hashable>(for dict: [Key: Any], nodes: [Node<Key>] = [], path: [Key] = []) -> [Node<Key>] {
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
                    result = navigationList(for: parseable, nodes: result, path: path)
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
    private func performOperation<Key: Hashable>(on dictionary: [Key: Any], at path: [Key], with operation: ([Key: Any]) -> [Key: Any], overwrite: Bool = false) -> [Key: Any] {
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
}

// MARK: Action methods

extension StickySchemaUpdater {
    private func renameEntity(from oldName: String, to newName: String) -> SchemaUpdateResult {
        let fileResult = FileHandler.renameFile(from: oldName, to: newName)
        switch fileResult {
        case .success:
            stickyLog("Entity changed from \(oldName) to \(newName)")
        case .error(let error):
            return .error(error.localizedDescription)
        }
        return .success
    }
    
    private func renameKey<Key: Hashable>(from oldKey: Key, to newKey: Key) -> ([Key: Any]) -> [Key: Any] {
        return { dict in
            var result = dict
            if let value = dict[oldKey] {
                result.removeValue(forKey: oldKey)
                result.updateValue(value, forKey: newKey)
            }
            return result
        }
    }
    
    private func removeKeys<Key: Hashable>(_ keys: [Key]) -> ([Key: Any]) -> [Key: Any] {
        return { dict in
            var result = dict
            for key in keys {
                result.removeValue(forKey: key)
            }
            return result
        }
    }
    
    private func newNode<Key: Hashable>(_ node: Any, for key: Key) -> ([Key: Any]) -> [Key: Any] {
        return { dict in
            var result = dict
            result.updateValue(node, forKey: key)
            return result
        }
    }
}

