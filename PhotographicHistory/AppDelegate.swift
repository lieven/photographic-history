//
//  AppDelegate.swift
//  PhotographicHistory
//
//  Created by Lieven Dekeyser on 14/06/2021.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.
		
		let window = UIWindow(frame: UIScreen.main.bounds)
		window.rootViewController = UINavigationController(rootViewController: ViewController())
		
		self.window = window
		
		window.makeKeyAndVisible()
		
		return true
	}
}

