import UIKit
import Sticky

class GroceryListViewController: UIViewController {
    
    private let groceryListCellName = "cell"
    private let notificationCenters: [NotificationCenter] = [.stickyUpdate, .stickyInsert, .stickyDelete, .stickyCreate]
    
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var tfGroceryItem: UITextField!
    
    private var groceryList: [FoodItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadGroceryListFromStore()
        
        // Subscribe to notifications for GroceryItem data store
        notificationCenters.forEach { [unowned self] notificationCenter in
            self.registerForNotifications(for: notificationCenter, selector: #selector(outputToConsole(notification:)), name: FoodItem.notificationName)
        }
    }
    
    deinit {
        notificationCenters.forEach { notificationCenter in
            deregisterForNotifications(for: notificationCenter, name: FoodItem.notificationName)
        }
    }
    
    @IBAction func addButton_pressed(_ sender: UIButton) {
        guard let groceryItemEntry = tfGroceryItem.text, !groceryItemEntry.isEmpty else { return }
        let groceryItem = FoodItem(itemName: groceryItemEntry)
        tfGroceryItem.text = nil
        saveAndUpdateList(with: groceryItem)
    }
    
    private func loadGroceryListFromStore() {
        groceryList = FoodItem.storedData
        tableView.reloadData()
    }
    
    private func saveAndUpdateList(with groceryItem: FoodItem) {
        groceryItem.saveToStore()
        loadGroceryListFromStore()
    }
    
    private func registerForNotifications(for notificationCenter: NotificationCenter, selector: Selector, name: Notification.Name) {
        notificationCenter.addObserver(
            self,
            selector: selector,
            name: name,
            object: nil
        )
    }
    
    private func deregisterForNotifications(for notificationCenter: NotificationCenter, name: Notification.Name) {
        notificationCenter.removeObserver(self, name: name, object: nil)
    }
    
    @objc private func outputToConsole(notification: NSNotification) {
        guard
            let first = notification.userInfo?.first,
            let key = first.key.base as? Action<FoodItem>,
            let value = first.value as? [FoodItem],
            let item = value.first
            else { return }
        let newValue = value.last
        
        var stickyMessage = "Sticky Notification Message: "
        switch key {
        case .insert:
            stickyMessage += "Inserted \(item.itemName) into \(type(of: item)) data store"
        case .update:
            stickyMessage += "\(item.itemName) amount updated from \(String(describing: item.amount) ) to \(String(describing: newValue!.amount)) in \(type(of: item)) data store"
        case .create:
            stickyMessage += "Created new data set for \(type(of: item)) and inserted \(item.itemName)"
        case .delete:
            stickyMessage += "\(item.itemName) deleted from \(type(of: item)) data store"
        default:
            stickyMessage += "Not known"
        }
        print(stickyMessage)
    }
}

//MARK: Table View Data Source

extension GroceryListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groceryList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: groceryListCellName) as? GroceryListTableViewCell else { return UITableViewCell() }
        cell.configure(with: groceryList[indexPath.row])
        cell.amountChanged = { [unowned self] (updatedAmountItem) in
            self.saveAndUpdateList(with: updatedAmountItem)
        }
        return cell
    }
}

//MARK: Table View Delegate

extension GroceryListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            let removedItem = groceryList.remove(at: indexPath.row)
            removedItem.deleteFromStore()
            tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
        }
    }
}
