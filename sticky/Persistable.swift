import Foundation

public protocol Persistable: Codable {}

public protocol UniqueIndexable {
    associatedtype Index: Equatable
    var index: Index { get }
}

public typealias Stickyable = Persistable & Equatable & UniqueIndexable

public extension Persistable {
    
    public static func read() -> [Self]? {
        return Self.decode(from: fileData)
    }
    
    public static func readAsync(completion: @escaping ([Self]?) -> Void) {
        DispatchQueue.main.async {
            completion(Self.decode(from: fileData))
        }
    }
    
    public static func dumpDataStoreToLog() {
        if Sticky.shared.configuration.logging {
            if Sticky.shared.configuration.async {
                DispatchQueue.main.async {
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
        guard let jsonData = data else { return nil }
        do {
            decoded = try JSONDecoder().decode([Self].self, from: jsonData)
        } catch {
            print("ERROR: \(name).\(#function) \(error.localizedDescription) Make sure any new data properties are marked as optional.")
            fatalError()
        }
        return decoded
    }
    
    private static var fileData: Data? {
        return FileHandler.read(from: filePath)
    }
    
    public static var filePath: String {
        return FileHandler.fullPath(for: Self.self)
    }
}

public extension Persistable where Self: Equatable {
    private var store: Store<Self> {
        let objects = Self.read()
        return Store(value: self, stored: objects)
    }
    
    private func storeAsync(completion: @escaping (Store<Self>) -> Void) {
        Self.readAsync { result in
            completion(Store(value: self, stored: result))
        }
    }
    
    public var isStored: Bool {
        if let _ = Self.read()?.index(of: self) {
            return true
        }
        return false
    }
    
    public func insertIfNew() {
        stickyLog("\(Self.name) saving without index")
        if Sticky.shared.configuration.async {
            storeAsync { store in
                self.save(in: store)
            }
        } else {
            save(in: self.store)
        }
    }
    
    public func deleteFromStore() {
        delete(from: self.store)
    }
    
    fileprivate func delete(from store: Store<Self>) {
        stickyLog("\(Self.name) removing data \(self)")
        store.remove()
    }
    
    fileprivate func save(in store: Store<Self>) {
        store.save()
    }
}

public extension Persistable where Self: Equatable & UniqueIndexable {
    private var indexStore: IndexStore<Self> {
        let objects = Self.read()
        return IndexStore(value: self, stored: objects)
    }
    
    private func indexStoreAsync(completion: @escaping (IndexStore<Self>) -> Void) {
        Self.readAsync { result in
            completion(IndexStore(value: self, stored: result))
        }
    }
    
    public func save() {
        stickyLog("\(Self.name) saving with index")
        if Sticky.shared.configuration.async {
            indexStoreAsync { store in
                self.save(in: store)
            }
        } else {
            save(in: self.indexStore)
        }
    }
}

internal extension Collection where Element: Persistable, Self: Codable {
    internal func saveWithOverwrite() {
        guard let encodedData = encode(self) else { return }
        let path = FileHandler.fullPath(for: Element.self)
        DispatchQueue.main.async {
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
