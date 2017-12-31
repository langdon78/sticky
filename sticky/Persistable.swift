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
            let name = String(describing: Self.self)
            let fileExt = ".json"
            let filename = name + fileExt
            guard let sourcePath = try? FileManager.default.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: false) else { return nil }
            let fullPath = sourcePath.appendingPathComponent(filename)
            print(fullPath)
            let manager = FileManager()
            let data = manager.contents(atPath: fullPath.path)
            if let jsonData = data {
                let carObject = try? JSONDecoder().decode([Self].self, from: jsonData)
                persistableCache?.stored = carObject
                return carObject
            }
            return nil
        }
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
        let encodedData = try? JSONEncoder().encode(self)
        let json = String(bytes: encodedData!, encoding: String.Encoding.utf8)
        print(json!)
        let name = String(describing: Element.self)
        let fileExt = ".json"
        let filename = name + fileExt
        guard let sourcePath = try? FileManager.default.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: false) else { return }
        let fullPath = sourcePath.appendingPathComponent(filename)
        try! encodedData?.write(to: URL(fileURLWithPath: fullPath.path))
    }
}
