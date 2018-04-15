import Foundation
import Sticky

protocol Saveable: StickyKeyable {
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
    
    init(itemName: String, amount: Int = 1) {
        self.itemName = itemName
        self.amount = amount
    }
}
