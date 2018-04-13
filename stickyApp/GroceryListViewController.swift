import UIKit

class GroceryListViewController: UIViewController {
    let groceryListCellName = "cell"
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tfGroceryItem: UITextField!
    
    var groceryList: [GroceryItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadFromStore()
    }
    
    @IBAction func addButton_pressed(_ sender: UIButton) {
        guard let groceryItemEntry = tfGroceryItem.text, !groceryItemEntry.isEmpty else { return }
        let groceryItem = GroceryItem(itemName: groceryItemEntry, amount: 1)
        tfGroceryItem.text = nil
        saveAndUpdateList(with: groceryItem)
    }
    
    func loadFromStore() {
        guard let storedList = GroceryItem.read() else { return }
        groceryList = storedList
        tableView.reloadData()
    }
    
    func saveAndUpdateList(with groceryItem: GroceryItem) {
        groceryItem.save()
        loadFromStore()
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
        cell.amountChanged = { [unowned self] (amount, itemName) in
            let updatedItem = GroceryItem(itemName: itemName, amount: amount)
            self.saveAndUpdateList(with: updatedItem)
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
            removedItem.delete()
            tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
        }
    }
}
