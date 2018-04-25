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

struct Store: Saveable {
    var key: Int {
        return id
    }
    var id: Int
    var town: String
}

struct FoodItem: Saveable {
    
    var key: String {
        return itemName
    }
    var itemName: String
    var quantity: Int
    var store: Store
    
    init(itemName: String, quantity: Int = 1, store: Store = Store(id: 0, town: "Portland")) {
        self.itemName = itemName
        self.quantity = quantity
        self.store = store
    }
}
