import Foundation

fileprivate let queueNameWrite = "com.sticky.write"
fileprivate let queueNameWriteAll = "com.sticky.writeAll"

public protocol Stickable: Codable {}

public protocol StickyKey {
    associatedtype Key: Equatable
    var key: Key { get }
}

public typealias Stickyable = Stickable & Equatable & StickyKey

public extension Stickable {
    
    public static func read() -> [Self]? {
        if let data = StickyCache.shared.stored, data is [Self] {
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
        if Sticky.shared.configuration.logging {
            if Sticky.shared.configuration.async {
                let queue = DispatchQueue(label: "com.sticky.log", qos: .background)
                queue.async {
                    guard let data = fileData else { return }
                    stickyLog("\(name): \(String(bytes: data, encoding: .utf8) ?? "")")
                }
            } else {
                stickyLog(debugDescription)
            }
        } else {
            print("\(name).\(#function) - Please enable logging in StickyConfiguration to see stored data")
        }
    }
    
    public static var name: String {
        return String(describing: Self.self)
    }
    
    public static func registerForNotification() {
        if notificationName == nil {
            Sticky.shared.registeredNotifications.append(Self.self)
        }
    }
    
    public static func deregisterForNotification() {
        if let index = Sticky.shared.registeredNotifications.index(where: { $0 == Self.self} ) {
            Sticky.shared.registeredNotifications.remove(at: index)
        }
    }
    
    public static var isRegisteredForNotifications: Bool {
        return notificationName != nil
    }
    
    public static var notificationName: NSNotification.Name? {
        if Sticky.shared.registeredNotifications.contains(where: { $0 == Self.self }) {
            return NSNotification.Name(name)
        }
        return nil
    }
    
    private static var debugDescription: String {
        guard let data = fileData else { return "" }
        return "\(name): \(String(bytes: data, encoding: .utf8) ?? "")"
    }
    
    private static func decode(from data: Data?) -> [Self]? {
        var decoded: [Self]? = nil
        guard let jsonData = data, !jsonData.isEmpty else { return nil }
        do {
            decoded = try JSONDecoder().decode([Self].self, from: jsonData)
        } catch {
            print("ERROR: \(name).\(#function) \(error.localizedDescription) Make sure any new data properties are marked as optional.")
            fatalError()
        }
        StickyCache.shared.stored = decoded
        return decoded
    }
    
    private static var fileData: Data? {
        return FileHandler.read(from: filePath)
    }
    
    public static var filePath: String {
        return FileHandler.fullPath(for: Self.self)
    }
}

public extension Stickable where Self: Equatable {
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
        stickyLog("\(Self.name) saving without key")
        self.save()
    }
    
    public func unstick() {
        delete()
    }
    
    // Implementation
    
    fileprivate func delete() {
        stickyLog("\(Self.name) removing data \(self)")
        let index = Self.read()?.index(of: self)
        Store.remove(value: self, from: Self.read(), at: index)
    }
    
    fileprivate func save() {
        let index = Self.read()?.index(of: self)
        Store.save(value: self, to: Self.read(), at: index)
    }
}

//MARK: - Stickable - Equatable & StickyKey

public extension Stickable where Self: Equatable & StickyKey {
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
    public func stickWithKey() {
        stickyLog("\(Self.name) saving with key")
        let index = Self.read()?
                    .map({ $0.key })
                    .index(of: self.key)
        Store.save(value: self, to: Self.read(), at: index)
    }
}

public extension Collection where Element: Stickable, Self: Codable {
    internal func saveWithOverwrite() {
        let queue = DispatchQueue(label: queueNameWriteAll)
        queue.async {
            guard let encodedData = self.encode(self) else { return }
            let path = FileHandler.fullPath(for: Element.self)
            FileHandler.write(data: encodedData, to: path)
        }
    }
    
    private func encode<T>(_ obj: T) -> Data? where T: Encodable {
        var data: Data? = nil
        do {
            data = try JSONEncoder().encode(obj)
        } catch let error {
            print("ERROR: \(error.localizedDescription)")
        }
        return data
    }
}

public extension Collection where Element: Stickable & Equatable, Self: Codable {
    public func stickAll() {
        if Sticky.shared.configuration.async {
            let queue = DispatchQueue(label: queueNameWrite)
            queue.sync {
                self.forEach { savable in
                    savable.stick()
                }
            }
        } else {
            self.forEach { savable in
                savable.stick()
            }
        }
    }

}

public extension Collection where Element: Stickyable, Self: Codable {
    public func stickAllWithKey() {
        if Sticky.shared.configuration.async {
            let queue = DispatchQueue(label: queueNameWrite)
            queue.async {
                self.forEach { savable in
                    savable.stickWithKey()
                }
            }
        } else {
            self.forEach { savable in
                savable.stickWithKey()
            }
        }
    }
    
}
