import UIKit
import Sticky

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        let stickyConfig = StickyConfiguration(async: true, logging: false)
        Sticky.configure(with: .custom(stickyConfig))
        
        return true
    }
}
