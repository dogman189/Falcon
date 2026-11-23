//
//  FalconApp.swift
//  Falcon
//
//  Created by Aanetra Vaidya on 11/15/26.
//

import SwiftUI

extension Color {
    static let appBackground = Color(red: 11 / 255, green: 20 / 255, blue: 38 / 255)
}

@main
struct FalconApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
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
