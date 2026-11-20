//
//  OrientationLock.swift
//  Falcon
//
//  Created by Aanetra Vaidya on 11/19/26.
//

import Combine
import UIKit

final class OrientationLock: ObservableObject {
    static let shared = OrientationLock()

    @Published var portraitOnly = true {
        didSet { apply() }
    }

    func apply() {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = windowScenes.first { $0.activationState == .foregroundActive }
            ?? windowScenes.first
        guard let scene else { return }

        // The deployment target is iOS 27.2, so these iOS 16+ APIs are always available.
        scene.requestGeometryUpdate(
            .iOS(interfaceOrientations: portraitOnly ? .portrait : .allButUpsideDown)
        )
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
