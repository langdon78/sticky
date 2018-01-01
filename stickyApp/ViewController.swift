//
//  ViewController.swift
//  stickyApp
//
//  Created by James Langdon on 12/31/17.
//  Copyright © 2017 James Langdon. All rights reserved.
//

import UIKit
import Sticky

struct College: Persistable {
    var name: String
    var ranking: Int?
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

class ViewController: UIViewController {
    @IBOutlet weak var notifcationLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let collegeNotification = College.notificationName else { return }
        print(College.notificationName!.rawValue)
        
        NotificationCenter.stickyInsert.addObserver(
            self,
            selector: #selector(updateLabel(notification:)),
            name: collegeNotification,
            object: nil
        )
        NotificationCenter.stickyUpdate.addObserver(
            self,
            selector: #selector(updateLabel(notification:)),
            name: collegeNotification,
            object: nil
        )
        
        let college = College(name: "Colorado", ranking: 18)

        college.save()
        
        let country = Country(name: "Ireland")
        country.save()
        print(College.debugDescription)
        print(College.filePath)
    }

    @objc func updateLabel(notification: NSNotification) {
        guard
            let first = notification.userInfo?.first,
            let key = first.key.base as? Action
            else { return }

        let value = first.value
        
        switch (key, value) {
        case (.insert, let change):
            guard let college = change as? College else { return }
            notifcationLabel.text = "Inserted \(college.name)"
        case (.update, let change):
            print("update")
            guard let college = change as? [College], let oldValue = college.first, let newValue = college.last else { return }
            notifcationLabel.text = "\(String(describing: oldValue.ranking!) ) updated to \(String(describing: newValue.ranking!))"
        case (.create, let change):
            guard let college = change as? College else { return }
            notifcationLabel.text = "Created new data set: \(college.name)"
        default:
            print("Not known")
        }

    }

}

