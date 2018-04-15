import UIKit
import Sticky

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        let stickyConfig = StickyConfiguration(async: true, logging: true)
        Sticky.configure(with: .custom(stickyConfig))
        performSchemaUpdates()
        return true
    }
    
    func performSchemaUpdates() {
        let bundle = Bundle.main
        guard let fileUrl = bundle.url(forResource: "sticky_schema_2", withExtension: "json") else { return }
        let stickyFile = StickySchemaFile(version: 2, fileUrl: fileUrl)
        guard let stickySchema = StickySchema.readSchemaFile(stickyFile) else { return }
        stickySchema.process()
    }
}
