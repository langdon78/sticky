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

public enum Action<StickyElement: StickyComparable>: Equatable {
    
    case insert(StickyElement, StickyDataSet<StickyElement>)
    case update(Int, StickyElement, StickyDataSet<StickyElement>)
    case create(StickyElement)
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

internal class Store {
    
    internal static func stickyAction<StickyElement: StickyComparable>(
            from stored: StickyDataSet<StickyElement>?,
            with value: StickyElement,
            at index: Int?) -> Action<StickyElement> {
        
        guard let objects = stored else { return .create(value) }
        guard let index = index else { return .insert(value, objects) }
        guard objects[index] == value else { return .update(index, value, objects) }
        return .none
        
    }
    
    internal static func remove<StickyElement: StickyComparable>(
            value: StickyElement,
            from dataSet: StickyDataSet<StickyElement>?,
            at index: Int?) {
        
        guard var dataSet = dataSet else { return }
        if let index = index {
            dataSet.remove(at: index)
            dataSet.saveWithOverwrite()
            stickyLog("\(value) deleted")
            let userInfo: [Action<StickyElement>: Any] = [.delete: [value]]
            NotificationCenter.stickyDelete.post(name: StickyElement.notificationName, object: nil, userInfo: userInfo)
        } else {
            stickyLog("\(value) could not be found")
        }
        
    }
    
    internal static func save<StickyElement: StickyComparable>(with action: Action<StickyElement>) {
        
        switch action {
        case .insert(let value, var dataSet):
            dataSet.append(value)
            dataSet.saveWithOverwrite()
            stickyLog("\(value) inserted")
            NotificationCenter.stickyInsert.post(name: StickyElement.notificationName, object: nil, userInfo: [action: [value]])
        case .update(let index, let value, var dataSet):
            let oldValue = dataSet[index]
            dataSet[index] = value
            dataSet.saveWithOverwrite()
            stickyLog("\(oldValue) updated to \(value)")
            NotificationCenter.stickyUpdate.post(name: StickyElement.notificationName, object: nil, userInfo: [action: [oldValue,value]])
        case .create(let value):
            let dataSet = Array(arrayLiteral: value)
            dataSet.saveWithOverwrite()
            stickyLog("Created new file for \(value))")
            NotificationCenter.stickyCreate.post(name: StickyElement.notificationName, object: nil, userInfo: [action: [value]])
        default:
            stickyLog("\(StickyElement.entityName): No action taken")
        }
        
    }
}
