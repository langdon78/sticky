import UIKit
import Sticky

struct Sample: Persistable {
    var id: String
    var index: Int?
    var guid: String?
    var balance: String?
    var picture: String?
    var age: Int?
    var eyeColor: String?
    var name: String?
    var gender: String?
    var company: String?
    var email: String?
    var phone: String?
    var address: String?
    var about: String?
    var registered: String?
}

extension Sample: Equatable {
    static func ==(lhs: Sample, rhs: Sample) -> Bool {
        return lhs.id == rhs.id
    }
}

struct College: Persistable {
    var name: String
    var ranking: Int?
    var city: String?
}

extension College: Equatable {
    static func ==(lhs: College, rhs: College) -> Bool {
        return lhs.name == rhs.name &&
        lhs.ranking == rhs.ranking
    }
}

extension College: UniqueIndexable {
    struct Index: Equatable {
        var name: String

        static func ==(lhs: Index, rhs: Index) -> Bool {
            return lhs.name == rhs.name
        }
    }
    
    var index: College.Index {
        return College.Index(name: self.name)
    }
}

struct Country: Persistable {
    var name: String
}

extension Country: Equatable {
    static func ==(lhs: Country, rhs: Country) -> Bool {
        return lhs.name == rhs.name
    }
}

struct Town: Persistable {
    var name: String
    var population: Int
}

extension Town: Equatable {
    static func ==(lhs: Town, rhs: Town) -> Bool {
        return lhs.name == rhs.name &&
        lhs.population == rhs.population
    }
}

class ViewController: UIViewController {
    @IBOutlet weak var notifcationLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let collegeNotification = College.notificationName else { return }
        guard let townNotification = Town.notificationName else { return }
        guard let sampleNotification = Sample.notificationName else { return }
        
        registerForNotifications(for: .stickyUpdate, selector: #selector(updateLabel(notification:)), name: collegeNotification)
        registerForNotifications(for: .stickyCreate, selector: #selector(updateLabel(notification:)), name: townNotification)
        registerForNotifications(for: .stickyCreate, selector: #selector(updateLabel(notification:)), name: sampleNotification)
        
        let college = College(name: "Colorado", ranking: 30, city: "Denver")
        college.save()
        College.dumpDataStoreToLog()
        
        let chicago = Town(name: "Chicago", population: 5987298)
        chicago.insertIfNew()
        
        let country = Country(name: "Japan")
        country.insertIfNew()
        
        guard let path = Bundle.main.path(forResource: "SampleJSON", ofType: "json") else { return }
        let url = URL(fileURLWithPath: path)
        let sampleJsonData = try? Data(contentsOf: url)
        do {
            let decode = try JSONDecoder().decode([Sample].self, from: sampleJsonData!)
            decode.forEach { $0.insertIfNew() }
        } catch {
            print(error.localizedDescription)
        }
        
    }
    
    private func registerForNotifications(for notificationCenter: NotificationCenter, selector: Selector, name: Notification.Name) {
        notificationCenter.addObserver(
            self,
            selector: selector,
            name: name,
            object: nil
        )
    }

    @objc func updateLabel(notification: NSNotification) {
        guard
            let first = notification.userInfo?.first,
            let key = first.key.base as? Action,
            let value = first.value as? [College],
            let college = value.first
            else { return }
        let newValue = value.last
        
        switch key {
        case .insert:
            notifcationLabel.text = "Inserted \(college.name)"
        case .update:
            notifcationLabel.text = "\(String(describing: college.ranking) ) updated to \(String(describing: newValue!.ranking))"
        case .create:
            notifcationLabel.text = "Created new data set: \(college.name)"
        case .delete:
            notifcationLabel.text = "\(college.name) deleted from data store"
        default:
            print("Not known")
        }
    }
}
