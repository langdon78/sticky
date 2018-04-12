import UIKit
import Sticky

struct Sample: Stickable {
    var id: Int
    var first_name: String
    var last_name: String
    var email: String
    var gender: String
    var ip_address: String
}

extension Sample: Equatable {
    static func ==(lhs: Sample, rhs: Sample) -> Bool {
        return lhs.id == rhs.id &&
        lhs.first_name == rhs.first_name &&
        lhs.first_name == rhs.first_name &&
        lhs.email == rhs.email &&
        lhs.gender == rhs.gender &&
        lhs.ip_address == rhs.ip_address
    }
}

extension Sample: StickyKey {
    struct Key: Equatable {
        var id: Int
        
        static func ==(lhs: Key, rhs: Key) -> Bool {
            return lhs.id == rhs.id
        }
    }
    var key: Sample.Key {
        return Sample.Key(id: self.id)
    }
}

struct College: Stickable {
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

extension College: StickyKey {
    struct Key: Equatable {
        var name: String

        static func ==(lhs: Key, rhs: Key) -> Bool {
            return lhs.name == rhs.name
        }
    }
    
    var key: College.Key {
        return College.Key(name: self.name)
    }
}

struct Country: Stickable {
    var name: String
}

extension Country: Equatable {
    static func ==(lhs: Country, rhs: Country) -> Bool {
        return lhs.name == rhs.name
    }
}

struct Town: Stickable {
    var name: String
    var population: Int
}

extension Town: Equatable {
    static func ==(lhs: Town, rhs: Town) -> Bool {
        return lhs.name == rhs.name &&
        lhs.population == rhs.population
    }
}

enum Rating: Int, Codable {
    case one = 1
    case two
    case three
    case four
}

struct Candy: Stickable, StickyKey, Equatable {
    typealias Key = Int
    var key: Key {
        return productId
    }
    var productId: Int
    var name: String
    var rating: Rating
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
        
        let college = College(name: "Maine", ranking: 60, city: "Portland")
        college.stickWithKey()
        
        DispatchQueue.main.async {
            College(name: "Kasnas", ranking: 5, city: "Lawrence").stickWithKey()
        }
        
        DispatchQueue.main.async {
            College(name: "Illinois", ranking: 1, city: "Champagne").stickWithKey()
        }
        
//        College.dumpDataStoreToLog()
        
        let chicago = Town(name: "New York", population: 6984298)
        chicago.stick()
        
        let country = Country(name: "Japan")
//        country.stick()
        country.unstick()
        

        
        var candyBar = Candy(productId: 1, name: "Snickers", rating: .four)
        candyBar.isStored
        
        candyBar.stickWithKey()
        
        candyBar.name = "Milky Way"
        
        Candy.read()
        
        candyBar.name = "Almond Joy"
        
        candyBar.stickWithKey()
        
        Candy.read()
        
        candyBar.unstick()
        
        
        print(Sticky.shared.configuration.localDirectory)
        
        Candy.read()
        
//        guard let path = Bundle.main.path(forResource: "Sample", ofType: "json") else { return }
//        let url = URL(fileURLWithPath: path)
//        let sampleJsonData = try? Data(contentsOf: url)
//
//        do {
//            let decode = try JSONDecoder().decode([Sample].self, from: sampleJsonData!)
//            // background
//            decode.stickAllWithKey()
//            // main thread
////            decode.forEach { $0.stick() }
//        } catch {
//            print(error.localizedDescription)
//        }
    }
    
    @IBAction func button_pressed(_ sender: UIButton) {
        let new = Sample(id: 17, first_name: "Wendy", last_name: "Cat", email: "stinkypoo@gmail.com", gender: "F", ip_address: "")
        new.stickWithKey()
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
