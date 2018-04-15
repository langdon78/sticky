import UIKit

class GroceryListTableViewCell: UITableViewCell {

    @IBOutlet weak var groceryName: UILabel!
    @IBOutlet weak var amount: UILabel!
    @IBOutlet weak var stepper: UIStepper!
    
    var amountChanged: ((FoodItem) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func configure(with item: FoodItem) {
        groceryName.text = item.itemName
        amount.text = String(item.amount)
        stepper.value = Double(item.amount)
    }

    @IBAction func amountStepper(_ sender: UIStepper, forEvent event: UIEvent) {
        guard let groceryItemName = groceryName.text else { return }
        let updatedItem = FoodItem(itemName: groceryItemName, amount: Int(sender.value))
        amountChanged?(updatedItem)
    }
}
