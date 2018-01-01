import Foundation

internal protocol Savable {
    associatedtype Object: Persistable
    func save()
}

fileprivate enum Action {
    case insert
    case update(Int)
    case create
    case delete
    case none
}

internal class Store<T: Persistable & Equatable>: Savable {
    typealias Object = T
    
    private var value: Object
    fileprivate var stored: [Object]?
    
    private var action: Action {
        if let objects = stored {
            if let index = storeIndex {
                if objects[index] != value {
                    return .update(index)
                }
            } else {
                return .insert
            }
        } else {
            return .create
        }
        return .none
    }
    
    var storeIndex: Int? {
        return stored?.index(of: value)
    }
    
    init(value: Object, stored: [Object]?) {
        self.value = value
        self.stored = stored
    }
    
    internal func save() {
        save(with: action)
    }
    
    private func save(with action: Action) {
        switch action {
        case .insert:
            stored?.append(value)
        case .update(let index):
            stored?[index] = value
        case .create:
            stored?.saveWithOverwrite()
        default:
            print("\(String(describing: Object.self)): No action taken")
        }
    }
}

internal class IndexStore<T: Stickyable>: Store<T> {
    typealias Object = T
    
    var objectIndex: Object.Index
    
    override var storeIndex: Int? {
        return stored?
            .map({ $0.index })
            .index(of: objectIndex)
    }
    
    override init(value: T, stored: [Object]?) {
        self.objectIndex = value.index
        super.init(value: value, stored: stored)
    }
}
