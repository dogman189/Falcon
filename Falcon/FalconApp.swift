//
//  FalconApp.swift
//  Falcon
//
//  Created by Aanetra Vaidya on 11/15/26.
//

import SwiftUI

@main
struct FalconApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        switch OrientationLock.shared.mode {
        case .auto:
            return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
        case .landscapeOnly:
            return .landscape
        }
    }
}
