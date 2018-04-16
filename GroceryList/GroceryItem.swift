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

struct FoodItem: Saveable {
    
    var key: String {
        return itemName
    }
    var itemName: String
    var quantity: Int
    
    init(itemName: String, quantity: Int = 1) {
        self.itemName = itemName
        self.quantity = quantity
    }
}
