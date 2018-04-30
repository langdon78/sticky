import Foundation

// Aliases for stored data
internal typealias StickyStoredEntity<Key: Hashable> = [[Key: Any]]
internal typealias StickyEntityName = String
internal typealias StickyEntityItem<Key: Hashable> = [Key: Any]

// Aliases for schema data
internal typealias StickySchemaMap<Key: Hashable> = [Key: Any]

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

internal struct StickySchemaAction<Key: Hashable> {
    var actionType: StickySchemaActionType<Key>
    var entityName: StickyEntityName
    var node: Node<Key>
}

internal struct Node<Key: Hashable> {
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
        stickyLog("----Begin update to version \(version)----", log: schemaLog)
        
        stickyLog("Importing schema file...", log: schemaLog)
        guard let stickySchemaMap = stickySchemaFile.toStickySchemaMap() else { return }

        stickyLog("Retrieving schema updates...", log: schemaLog)
        guard let schemaActions = schemaActions(from: stickySchemaMap) else { return }
        
        stickyLog("Processing updates...", log: schemaLog)
        let result = processSchemaActions(for: schemaActions)
        switch result {
        case .success:
            stickyLog("Successfully updated Sticky schema to version \(version)", log: schemaLog)
            increment(to: version)
            stickyLog("----End update----", log: schemaLog)
        case .error(let error):
            stickyLog((error as? StickyError)?.description ?? error.localizedDescription, logAction: .error, log: schemaLog)
        }
    }
}

// MARK: Schema parsing and update methods

extension StickySchemaUpdater {
    
    internal func processSchemaActions<Key: Hashable>(for schemaActions: [StickySchemaAction<Key>]) -> StickyResult {
        var memoryCache: [StickyEntityName: StickyStoredEntity<Key>] = [:]
        
        for action in schemaActions {
            guard var stored = storedEntity(for: action.entityName, memoryStore: memoryCache) else { return .error(StickyError.dataFileDoesNotExist(action.entityName)) }
            
            stickyLog("Processing \"\(action.actionType.rawValue)\"", log: schemaLog)
            let actionResult = processSchemaAction(for: action, on: &stored)
            if actionResult != .success {
                return actionResult
            }
            
            // Remove old entity from memory store if entity is renamed
            if action.actionType == .renameEntity {
                memoryCache.removeValue(forKey: action.entityName)
            } else {
                memoryCache.updateValue(stored, forKey: action.entityName)
            }
            stored = []
        }
        
        // Write data to file
        for (entityName, entity) in memoryCache {
            let writeResult = FileHandler.writeJsonFile(for: entity, to: entityName)
            return writeResult
        }
        
        return .success
    }
    
    internal func processSchemaAction<Key: Hashable>(for data: StickySchemaAction<Key>,
                                                    on storedEntity: inout StickyStoredEntity<Key>) -> StickyResult {
        if data.actionType == .renameEntity,
            let oldName = data.node.key as? String,
            let newName = data.node.value as? String {
            stickyLog("Performing file rename", log: schemaLog)
            return renameEntity(from: oldName, to: newName)
        }
        
        var resultEntity: StickyStoredEntity<Key> = []
        for item in storedEntity {
            stickyLog("Performing action \(data.actionType) on entity \(data.entityName)", log: schemaLog)
            let action = data.actionType
            switch action {
            case .removeProperty:
                stickyLog("Removing property \"\(data.node.value)\" for \"\(data.entityName)\"", log: schemaLog)
                if let properties = data.node.value as? [Key] {
                    var pathWithKey = data.node.path
                    pathWithKey.append(data.node.key)
                    let updatedItem = performOperation(on: item, at: pathWithKey, with: removeKeys(properties))
                    resultEntity.append(updatedItem)
                }
            case .newProperty:
                stickyLog("Adding new property \"\(data.node.key)\" with default value \"\(data.node.value)\" to \"\(data.entityName)\"", log: schemaLog)
                let updatedItem = performOperation(on: item, at: data.node.path, with: newNode(data.node.value, for: data.node.key), overwrite: true)
                resultEntity.append(updatedItem)
            case .renameProperty:
                stickyLog("Renaming property \"\(data.node.key)\" to \"\(data.node.value)\" for \"\(data.entityName)\"", log: schemaLog)
                let oldKey = data.node.key
                if let newKey = data.node.value as? Key {
                    let updatedItem = performOperation(on: item, at: data.node.path, with: renameKey(from: oldKey, to: newKey))
                    resultEntity.append(updatedItem)
                }
            default:
                return .error(StickyError.noActionTaken)
            }
        }
        storedEntity = resultEntity
        stickyLog("Success", log: schemaLog)
        return .success
    }
    
    private func entityFromMemory<Key: Hashable>(for entityName: StickyEntityName, from dataStore: [StickyEntityName: StickyStoredEntity<Key>]) -> StickyStoredEntity<Key>? {
        return dataStore[entityName]
    }
    
    private func entityFromDisk<Key: Hashable>(for entityName: StickyEntityName) -> StickyStoredEntity<Key>? {
        return FileHandler.readJsonFile(for: entityName)
    }
    
    private func storedEntity<Key: Hashable>(for entity: StickyEntityName,
                                             memoryStore: [StickyEntityName: StickyStoredEntity<Key>]) -> StickyStoredEntity<Key>? {
        if let memory = entityFromMemory(for: entity, from: memoryStore) {
            return memory
        } else if let disk: StickyStoredEntity<Key> = entityFromDisk(for: entity) {
            return disk
        } else {
            return nil
        }
    }
    
    internal func schemaActions<Key: Hashable>(from schema: StickySchemaMap<Key>) -> [StickySchemaAction<Key>]? {
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
                StickyError.emptySchemaFile.outputToLog(schemaLog)
                return nil
        }
        
        guard let actionType = StickySchemaActionType(actionName) else {
                StickyError.invalidAction(actionName as? String).outputToLog(schemaLog)
                return nil
        }
        
        guard let entityName = entityName(for: actionType, nodeKey: node.key, path: &path) else {
            StickyError.unableToParseEntityName(actionType.rawValue).outputToLog(schemaLog)
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

internal extension StickySchemaUpdater {
    func renameEntity(from oldName: String, to newName: String) -> StickyResult {
        return FileHandler.renameFile(from: oldName, to: newName)
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

