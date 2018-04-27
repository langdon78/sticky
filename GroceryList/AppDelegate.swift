import UIKit
import Sticky

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        let stickyConfig = StickyConfiguration(async: true, logStyle: .verbose, rollbackToSchemaVersion: nil)
        Sticky.configure(with: .custom(stickyConfig))
        
        // In order to use the sample schema update provided,
        // please copy Schema/GroceryItem.json to the "Documents"
        // path listed in the console output. Remove FoodItem.json
        // if present and uncomment the following code...
        
        // StoredDataSchemaUpdater.processUpdates()
        
        return true
    }
}
