import Foundation

public protocol Persistable: Codable {}

class PersistableCache {
    var stored: [Persistable]?
    static let shared: PersistableCache = PersistableCache()
    
    private init(stored: [Persistable]? = nil) {
        self.stored = stored
    }
}

protocol Savable {
    associatedtype Object: Persistable
    var index: Int { get }
    func save()
}

class Store<T: Persistable>: Savable {
    var index: Int
    
    typealias Object = T
    var value: Object
    init(value: T, index: Int) {
        self.value = value
        self.index = index
    }
    
    func save() {
        if var objects = Object.read() {
            if index < objects.endIndex {
                objects[index] = self.value
            } else {
                objects.append(self.value)
            }
            objects.saveAll()
        }
    }
}

public extension Persistable {
    private static var persistableCache: PersistableCache? {
        return PersistableCache.shared
    }
    
    public static func read(updateCache: Bool = false) -> [Self]? {
        if let cache = persistableCache?.stored, !updateCache {
            return cache as? [Self]
        } else {
            return Self.decode(from: fileData)
        }
    }
    
    public static var debugDescription: String {
        guard let data = fileData else { return "" }
        let objectName = String(describing: Self.self)
        return "\(objectName): \(String(bytes: data, encoding: .utf8) ?? "")"
    }
    
    private static func decode(from data: Data?) -> [Self]? {
        guard let jsonData = data else { return nil }
        let carObject = try? JSONDecoder().decode([Self].self, from: jsonData)
        persistableCache?.stored = carObject
        return carObject
    }
    
    private static var fileData: Data? {
        let path = FileHandler.fullPath(for: Self.self)
        return FileHandler.read(from: path)
    }
}

public extension Persistable where Self: Equatable {
    private func retrieve() -> Store<Self> {
        guard let stored = Self.read() else {
            return Store(value: self, index: 0)
        }
        if let index = stored.index(of: self) {
            return Store(value: self, index: index)
        } else {
            return Store(value: self, index: stored.endIndex)
        }
    }
    
    private var store: Store<Self> {
        let stored = self.retrieve()
        return stored
    }
    
    public var isStored: Bool {
        if let _ = Self.read()?.index(of: self) {
            return true
        }
        return false
    }
    
    public func save() {
        self.store.save()
        let _ = Self.read(updateCache: true)
    }
    
    public func replace(with object: Self) {
        let store = self.store
        store.value = object
        store.save()
        let _ = Self.read(updateCache: true)
    }
}

public extension Collection where Element: Persistable, Self: Codable {
    public func saveAll() {
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
