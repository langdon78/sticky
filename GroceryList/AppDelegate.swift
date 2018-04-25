import UIKit
import Sticky

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        let stickyConfig = StickyConfiguration(async: true, logging: true, rollbackToSchemaVersion: 2)
        Sticky.configure(with: .custom(stickyConfig))
        StoredDataSchemaUpdater.processUpdates()
        
        return true
    }
}
