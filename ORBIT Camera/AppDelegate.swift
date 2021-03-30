//
//  AppDelegate.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/02/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

import UIKit
import os

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        try! AppDatabase.setup(application)
        AppUploader.setup()
        
        // Delay allows authCredential be set on app launch
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .seconds(2)) {
            UNUserNotificationCenter.current().getNotificationSettings { (notificationSettings) in
                if notificationSettings.authorizationStatus == .authorized {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { (granted, error) in
                        if granted {
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                                UNUserNotificationCenter.current().delegate = self
                            }
                        }
                        os_log("Notifications granted: %{public}s", granted ? "Yes" : "No")
                    }
                }
            }
        }
        
        return true
    }
    
    // MARK: URLSession
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        appNetwork.completionHandler = completionHandler
    }

    // MARK: Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        APNS.uploadDeviceToken(token: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        os_log("didFailToRegisterForRemoteNotificationsWithError")
        assertionFailure()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        guard let updateVideo = userInfo["video"] as? String,
              let updateThing = userInfo["thing"] as? String
        else {
            //FIXME: go do something, or somesuch
            print("userNotificationCenter didReceive", response)
            completionHandler()
            return
        }
        //FIXME: go to that video/thing or somesuch
        print("userNotificationCenter didReceive", response, updateVideo, updateThing)
        completionHandler()
    }
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

