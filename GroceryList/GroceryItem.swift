import Foundation
import Sticky

protocol Saveable: StickyKeyable {
    
    associatedtype Key
    var key: Key { get }
    static var storedData: [Self] { get }
    
    func saveToStore()
    func deleteFromStore()
}

extension Saveable {
    
    static var storedData: [Self] {
        return self.read() ?? []
    }
    
    func saveToStore() {
        self.stickWithKey()
    }
    
    func deleteFromStore() {
        self.unstick()
    }
}

struct GroceryItem: Saveable {
    
    var key: String {
        return itemName
    }
    var itemName: String
    var amount: Int
    
    init(itemName: String, amount: Int = 1) {
        self.itemName = itemName
        self.amount = amount
    }
}
