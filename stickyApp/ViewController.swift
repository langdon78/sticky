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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let college = College(name: "USC", ranking: 19)
//        let uofi = College(name: "University of Illinois")
//
//        let colleges = [bradley, uofi]
//

        college.save()
        
        let country = Country(name: "Canada")
        country.save()
        print(College.debugDescription)
        print(College.filePath)
    }



}

