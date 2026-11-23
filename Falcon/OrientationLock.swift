import Combine
import UIKit

final class OrientationLock: ObservableObject {
    static let shared = OrientationLock()

    enum Mode {
        /// Allows both portrait and landscape orientation (for library, settings, and packer).
        case auto
        /// Locks strictly to landscape for immersive gameplay.
        case landscapeOnly
    }

    @Published var mode: Mode = .auto {
        didSet { apply() }
    }

    /// Backwards compatibility bridge
    var portraitOnly: Bool {
        get { mode != .landscapeOnly }
        set { mode = newValue ? .auto : .landscapeOnly }
    }

    func apply() {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = windowScenes.first { $0.activationState == .foregroundActive }
            ?? windowScenes.first
        guard let scene else { return }

        switch mode {
        case .auto:
            let mask: UIInterfaceOrientationMask = UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        case .landscapeOnly:
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
