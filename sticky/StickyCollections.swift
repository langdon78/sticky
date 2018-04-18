import Foundation

fileprivate let queueNameWrite = "com.sticky.write"
fileprivate let queueNameWriteAll = "com.sticky.writeAll"

public extension Collection where Element: Stickable, Self: Codable {
    internal func saveWithOverwrite() {
        guard let dataSet = self as? [Stickable] else { return }
        cache.stored.updateValue(dataSet, forKey: Element.entityName)
        queueToFile()
    }
    
    private func queueToFile() {
        let queue = DispatchQueue(label: queueNameWriteAll)
        queue.async {
            guard let encodedData = self.encode(self) else { return }
            let url = FileHandler.url(for: Element.entityName)
            FileHandler.write(data: encodedData, to: url.path)
        }
    }
    
    private func encode<T>(_ obj: T) -> Data? where T: Encodable {
        var data: Data? = nil
        do {
            data = try JSONEncoder().encode(obj)
        } catch let error {
            stickyLog("ERROR: \(error.localizedDescription)", logAction: .error)
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
