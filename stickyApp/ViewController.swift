//
//  ViewController.swift
//  stickyApp
//
//  Created by James Langdon on 12/31/17.
//  Copyright © 2017 James Langdon. All rights reserved.
//

import UIKit
import Sticky

class College: Persistable {
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

extension College: Equatable {
    static func ==(lhs: College, rhs: College) -> Bool {
        return lhs.name == rhs.name
    }
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let bradley = College(name: "Illinois State University")
        let uofi = College(name: "University of Illinois")

        let colleges = [bradley, uofi]


        bradley.replace(with: College(name: "DUke"))
        College.read()?.map { print($0.name) }
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

