import Foundation

public protocol Persistable: Codable {}

public protocol UniqueIndexable {
    associatedtype Index: Equatable
    var index: Index { get }
}

public typealias Stickyable = Persistable & Equatable & UniqueIndexable

public extension Persistable {
    
    public static func read(updateCache: Bool = false) -> [Self]? {
        return Self.decode(from: fileData)
    }
    
    public static var debugDescription: String {
        guard let data = fileData else { return "" }
        let objectName = String(describing: Self.self)
        return "\(objectName): \(String(bytes: data, encoding: .utf8) ?? "")"
    }
    
    private static func decode(from data: Data?) -> [Self]? {
        var decoded: [Self]? = nil
        guard let jsonData = data else { return nil }
        do {
            decoded = try JSONDecoder().decode([Self].self, from: jsonData)
        } catch {
            print(error.localizedDescription)
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
    
    public var isStored: Bool {
        if let _ = Self.read()?.index(of: self) {
            return true
        }
        return false
    }
    
    public func save() {
        print("without index")
        save(in: self.store)
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
    
    public func save() {
        print("with index")
        save(in: self.indexStore)
    }
}

internal extension Collection where Element: Persistable, Self: Codable {
    internal func saveWithOverwrite() {
        guard let encodedData = encode(self) else { return }
        let path = FileHandler.fullPath(for: Element.self)
        FileHandler.write(data: encodedData, to: path)
    }
    
    private func encode<T>(_ obj: T) -> Data? where T: Encodable {
        var data: Data? = nil
        do {
            data = try JSONEncoder().encode(obj)
        } catch let error {
            print(error.localizedDescription)
        }
        return data
    }
}
