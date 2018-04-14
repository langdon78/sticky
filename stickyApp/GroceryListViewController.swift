import UIKit

class GroceryListViewController: UIViewController {
    let groceryListCellName = "cell"
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tfGroceryItem: UITextField!
    
    var groceryList: [GroceryItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadGroceryListFromStore()
    }
    
    @IBAction func addButton_pressed(_ sender: UIButton) {
        guard let groceryItemEntry = tfGroceryItem.text, !groceryItemEntry.isEmpty else { return }
        let groceryItem = GroceryItem(itemName: groceryItemEntry)
        tfGroceryItem.text = nil
        saveAndUpdateList(with: groceryItem)
    }
    
    func loadGroceryListFromStore() {
        guard let storedList = GroceryItem.read() else { return }
        groceryList = storedList
        tableView.reloadData()
    }
    
    func saveAndUpdateList(with groceryItem: GroceryItem) {
        groceryItem.save()
        loadGroceryListFromStore()
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
            removedItem.delete()
            tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
        }
    }
}
