import Foundation
import Sticky

protocol Saveable: Stickyable {
    var key: String { get }
    
    func save()
    func delete()
}

extension Saveable {
    func save() {
        self.stickWithKey()
    }
    
    func delete() {
        self.unstick()
    }
}

struct GroceryItem: Saveable {
    typealias Key = String
    var key: Key {
        return itemName
    }
    var itemName: String
    var amount: Int
}
