import Foundation

fileprivate let queueNameWrite = "com.sticky.write"
fileprivate let queueNameWriteAll = "com.sticky.writeAll"

public protocol StickyPromise {
    func after(_ completion: () -> Void)
}

public extension StickyPromise {
    func after(_ completion: () -> Void) {
        completion()
    }
}

public protocol Stickable: Codable, StickyPromise {}

public protocol StickyKey {
    associatedtype Key: Equatable
    var key: Key { get }
}

public typealias StickyComparable = Stickable & Equatable
public typealias StickyKeyable = StickyComparable & StickyKey
public typealias StickyDataSet<T: StickyComparable> = [T]

public extension CodingUserInfoKey {
    public static let codedTypeKey = CodingUserInfoKey(rawValue: "codedTypeName")!
}

public extension Decoder {
    public var codedTypeName: String {
        return userInfo[CodingUserInfoKey.codedTypeKey] as? String ?? ""
    }
}

public extension Stickable {
    
    public static func read() -> [Self]? {
        if let data = StickyCache.shared.stored, !data.isEmpty, data is [Self] {
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
    
    public static var notificationName: NSNotification.Name {
            return NSNotification.Name(name)
    }
    
    private static var debugDescription: String {
        guard let data = fileData else { return "" }
        return "\(name): \(String(bytes: data, encoding: .utf8) ?? "")"
    }
    
    private static func decode(from data: Data?) -> [Self]? {
        var decoded: [Self]? = nil
        guard let jsonData = data, !jsonData.isEmpty else { return nil }
        do {
            let decoder = JSONDecoder()
            let describedType = String(describing: Self.self)
            decoder.userInfo = [CodingUserInfoKey.codedTypeKey: describedType]
            decoded = try decoder.decode([Self].self, from: jsonData)
        } catch {
            var errorMessage = "ERROR: \(name).\(#function) \(error.localizedDescription) "
            errorMessage += handleDecodeError(error) ?? ""
            errorMessage += debugDescription
            stickyLog(errorMessage)
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
        let stickyAction = Store.stickyAction(from: Self.read(), with: self, at: index)
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
        stickyLog("\(Self.name) saving with key")
        let index = Self.read()?
                    .map({ $0.key })
                    .index(of: self.key)
        let stickyAction = Store.stickyAction(from: Self.read(), with: self, at: index)
        Store.save(with: stickyAction)
        return self as StickyPromise
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

public extension Collection where Element: Stickable & Equatable & StickyPromise, Self: Codable {
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

public extension Collection where Element: StickyKeyable & StickyPromise, Self: Codable {
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

