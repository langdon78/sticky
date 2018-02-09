import Foundation

internal protocol Savable {
    associatedtype Object: Stickable
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
        switch (lhs,rhs) {
        case (.update(let a), .update(let b)):
            return a == b
        default:
            return lhs.hashValue == rhs.hashValue
        }
    }
}

internal class Store {
    private static func getAction<T: Stickable & Equatable>(from stored: [T]?, with value: T, at index: Int?) -> Action {
        if let objects = stored {
            if let index = index {
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
    
    internal static func remove<T: Stickable & Equatable>(value: T, from dataSet: [T]?, at index: Int?) {
        var stored = dataSet
        if let index = index {
            stored?.remove(at: index)
            stickyLog("\(value) deleted")
            notify(from: .stickyDelete, with: [.delete: [value]])
            stored?.saveWithOverwrite()
        } else {
            stickyLog("\(value) could not be found")
        }
    }
    
    internal static func save<T: Stickable & Equatable>(value: T, to dataSet: [T]?, at index: Int?) {
        let action = getAction(from: dataSet, with: value, at: index)
        var stored = dataSet
        switch action {
        case .insert:
            stored?.append(value)
            stickyLog("\(value) inserted")
            stored?.saveWithOverwrite()
            notify(from: .stickyInsert, with: [action: [value]], notificationName: T.notificationName)
        case .update(let index):
            guard let oldValue = stored?[index] else { return }
            stored?[index] = value
            stickyLog("\(oldValue) updated to \(value)")
            stored?.saveWithOverwrite()
            notify(from: .stickyUpdate, with: [action: [oldValue,value]], notificationName: T.notificationName)
        case .create:
            [value].saveWithOverwrite()
            notify(from: .stickyCreate, with: [action: [value]], notificationName: T.notificationName)
            stickyLog("Created new file for \(value))")
        default:
            stickyLog("\(T.name): No action taken")
        }
        StickyCache.shared.stored = stored
    }
    
    private static func notify(from notificationCenter: NotificationCenter, with change: [Action: Any]?, notificationName: NSNotification.Name? = nil) {
        if let notificationName = notificationName {
            notificationCenter.post(name: notificationName, object: nil, userInfo: change)
        }
    }
}
