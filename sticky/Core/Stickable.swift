import Foundation

fileprivate let stickyDataDumpLogQueue = "queue.sticky.log"

public extension Stickable {
    
    public static func read() -> [Self]? {
        if let data = cache.stored[entityName], !data.isEmpty {
            stickyLog("Read from cache")
            return data as? [Self]
        } else {
            return Self.decode(from: fileData)
        }
    }
    
    public static func readAsync(completion: @escaping ([Self]?) -> Void) {
        DispatchQueue.main.async {
            completion(Self.decode(from: fileData))
        }
    }
    
    public static func dumpDataStoreToLog() {
        if Sticky.shared.configuration.logStyle == .verbose {
            if Sticky.shared.configuration.async {
                let queue = DispatchQueue(label: stickyDataDumpLogQueue, qos: .background)
                queue.async {
                    guard let data = fileData else { return }
                    stickyLog("\(entityName): \(String(bytes: data, encoding: .utf8) ?? "")")
                }
            } else {
                stickyLog(debugDescription)
            }
        } else {
            stickyLog("\(entityName).\(#function) - Please enable logging in StickyConfiguration to see stored data")
        }
    }
    
    public static var entityName: String {
        return String(describing: Self.self)
    }
    
    public static var notificationName: NSNotification.Name {
            return NSNotification.Name(entityName)
    }
    
    private static var debugDescription: String {
        guard let data = fileData else { return "" }
        return "\(entityName): \(String(bytes: data, encoding: .utf8) ?? "")"
    }
    
    private static func decode(from data: Data?) -> [Self]? {
        var decoded: [Self]? = nil
        guard let jsonData = data, !jsonData.isEmpty else { return nil }
        
        do {
            let decoder = JSONDecoder()
            decoder.userInfo = [CodingUserInfoKey.codedTypeKey: entityName]
            decoded = try decoder.decode([Self].self, from: jsonData)
        } catch {
            var errorMessage = "ERROR: \(entityName).\(#function) \(error.localizedDescription) "
            errorMessage += handleDecodeError(error) ?? ""
            errorMessage += debugDescription
            stickyLog(errorMessage, logAction: .error)
        }
        
        // Write to cache if data is returned and cache is empty
        if let decoded = decoded, cache.stored.isEmpty {
            cache.stored.updateValue(decoded, forKey: entityName)
        }
        
        return decoded
    }
    
    private static var fileData: Data? {
        return FileHandler.read(from: filePath)
    }
    
    public static var filePath: String {
        return FileHandler.url(for: Self.entityName).path
    }
    
    private static func handleDecodeError(_ error: Error) -> String? {
        guard let decodeError = error as? DecodingError else { return nil }
        switch decodeError {
        case .keyNotFound(_, let context): return context.debugDescription
        case .dataCorrupted(let context): return context.debugDescription
        case .typeMismatch(_, let context): return context.debugDescription
        case .valueNotFound(_, let context): return context.debugDescription
        }
    }
}

public extension Stickable where Self: Equatable & StickyPromise {
    // Public API
    ///
    /// Checks to see if data object is stored locally.
    ///
    public var isStored: Bool {
        if let _ = Self.read()?.index(of: self) {
            return true
        }
        return false
    }
    ///
    /// If data object conforms to Equatable, this method will
    /// scan the local store and find the first value that matches
    /// the Equatable (==) definition.
    ///
    /// This method will always insert a new data object unless
    /// data is completely unchanged, then it will do nothing.
    ///
    /// Use this if data object doesn't need to update and storage space
    /// and performance are less concerning. More suited for transactional data.
    ///
    public func stick() {
        stickyLog("\(Self.entityName) saving without key")
        self.save()
    }
    
    public func unstick() {
        delete()
    }
    
    // Implementation
    
    fileprivate func delete() {
        let dataSet = Self.read()
        stickyLog("\(Self.entityName) removing data \(self)")
        let index = dataSet?.index(of: self)
        Store.remove(value: self, from: dataSet, at: index)
    }
    
    fileprivate func save() {
        let dataSet = Self.read()
        let index = dataSet?.index(of: self)
        let stickyAction = Store.stickyAction(from: dataSet, with: self, at: index)
        Store.save(with: stickyAction)
    }
}

//MARK: - Stickable - Equatable & StickyKey

public extension Stickable where Self: Equatable & StickyKey & StickyPromise {
    // Public API
    ///
    /// When data object conforms to StickyKey, this method will seek
    /// the unique stored data element that matches the key and either:
    ///   1. Update the non-key values if needed
    ///   2. Store the new object
    ///   3. Do nothing if data is unchanged.
    ///
    /// Use this method if you have data objects with one or two
    /// properties that ensure uniqueness and need to update values frequently.
    ///
    @discardableResult public func stickWithKey() -> StickyPromise {
        let dataSet = Self.read()
        stickyLog("\(Self.entityName) saving with key")
        let index = dataSet?
                    .map({ $0.key })
                    .index(of: self.key)
        let stickyAction = Store.stickyAction(from: dataSet, with: self, at: index)
        Store.save(with: stickyAction)
        return self as StickyPromise
    }
    
    public func unstick() {
        let dataSet = Self.read()
        stickyLog("\(Self.entityName) removing data \(self)")
        let index = dataSet?
            .map({ $0.key })
            .index(of: self.key)
        Store.remove(value: self, from: dataSet, at: index)
    }
}
