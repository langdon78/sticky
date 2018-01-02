//
//  AppDelegate.swift
//  stickyApp
//
//  Created by James Langdon on 12/31/17.
//  Copyright © 2017 James Langdon. All rights reserved.
//

import UIKit
import Sticky

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        let stickyConfig = StickyConfiguration(async: true, logging: true)
        Sticky.configure(with: .custom(stickyConfig))
        
        College.registerForNotification()
        Town.registerForNotification()
        
        return true
    }
}
