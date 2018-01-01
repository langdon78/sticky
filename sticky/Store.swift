import Foundation

internal protocol Savable {
    associatedtype Object: Persistable
    func save()
}

public extension NotificationCenter {
    static let stickyInsert = NotificationCenter()
    static let stickyUpdate = NotificationCenter()
    static let stickyCreate = NotificationCenter()
    static let stickyDelete = NotificationCenter()
}

public enum Action {
    case insert
    case update(Int)
    case create
    case delete
    case none
}

extension Action: Hashable {
    public var hashValue: Int {
        switch self {
        case .insert: return 0
        case .create: return 1
        case .delete: return 2
        case .update: return 3
        case .none: return 4
        }
    }
}

extension Action: CustomStringConvertible {
    public var description: String {
        switch self {
        case .insert: return "Insert"
        case .create: return "Create"
        case .delete: return "Delete"
        case .update: return "Update"
        case .none: return "No Action"
        }
    }
}

extension Action: Equatable {
    public static func ==(lhs: Action, rhs: Action) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
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
            stickyLog("\(value) inserted")
            notify(from: .stickyInsert, with: [action: [value]])
        case .update(let index):
            guard let oldValue = stored?[index] else { return }
            stored?[index] = value
            stickyLog("\(oldValue) updated to \(value)")
            notify(from: .stickyUpdate, with: [action: [oldValue,value]])
        case .create:
            stored?.saveWithOverwrite()
            notify(from: .stickyCreate, with: [action: [value]])
            stickyLog("Created new file for \(value))")
        default:
            stickyLog("\(Object.name): No action taken")
        }
        stored?.saveWithOverwrite()
    }
    
    private func notify(from notificationCenter: NotificationCenter, with change: [Action: Any]?) {
        if let notificationName = Object.notificationName {
            notificationCenter.post(name: notificationName, object: nil, userInfo: change)
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
