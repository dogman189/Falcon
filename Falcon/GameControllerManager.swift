import Combine
import Foundation
import GameController

/// Manages connected game controllers (MFi, Xbox, PlayStation, Nintendo Switch)
/// and translates physical controller input into menu navigation events.
@MainActor
final class GameControllerManager: ObservableObject {
    static let shared = GameControllerManager()

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var controllerName: String = "Controller"

    /// Disables menu input interception when in-game so WebKit receives raw gamepad events.
    var isEnabled: Bool = true {
        didSet {
            if isEnabled {
                configureCurrentControllers()
            }
        }
    }

    var onNavigateLeft: (() -> Void)?
    var onNavigateRight: (() -> Void)?
    var onNavigateUp: (() -> Void)?
    var onNavigateDown: (() -> Void)?
    var onActionA: (() -> Void)? // Launch / Select / Toggle
    var onActionB: (() -> Void)? // Back
    var onActionX: (() -> Void)? // Add Game
    var onShoulderLeft: (() -> Void)? // L1 / LB (Previous Tab)
    var onShoulderRight: (() -> Void)? // R1 / RB (Next Tab)
    var onInGameMenuToggle: (() -> Void)? // Guide/Home button while in-game

    private var cancellables = Set<AnyCancellable>()
    private var lastThumbstickMoveTime: Date = .distantPast
    private let thumbstickRepeatInterval: TimeInterval = 0.22
    private let thumbstickDeadzone: Float = 0.45

    init() {
        setupObservers()
        updateConnectedControllers()
    }

    private func setupObservers() {
        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateConnectedControllers()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateConnectedControllers()
            }
            .store(in: &cancellables)
    }

    private func updateConnectedControllers() {
        let controllers = GCController.controllers()
        if let first = controllers.first {
            isConnected = true
            controllerName = cleanControllerName(first.vendorName ?? "Game Controller")
            configureController(first)
        } else {
            isConnected = false
            controllerName = "No Controller"
        }
    }

    private func configureCurrentControllers() {
        for controller in GCController.controllers() {
            configureController(controller)
        }
    }

    private func configureController(_ controller: GCController) {
        if let gamepad = controller.extendedGamepad {
            configureExtendedGamepad(gamepad)
        } else if let micro = controller.microGamepad {
            configureMicroGamepad(micro)
        }
    }

    private func configureExtendedGamepad(_ gamepad: GCExtendedGamepad) {
        // D-pad Navigation
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleDirection(.left) }
            }
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleDirection(.right) }
            }
        }
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleDirection(.up) }
            }
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleDirection(.down) }
            }
        }

        // Left Stick Navigation (with deadzone & throttling)
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                guard let self = self, self.isEnabled else { return }
                let now = Date()
                guard now.timeIntervalSince(self.lastThumbstickMoveTime) >= self.thumbstickRepeatInterval else { return }

                if abs(x) > abs(y) {
                    if x > self.thumbstickDeadzone {
                        self.lastThumbstickMoveTime = now
                        self.handleDirection(.right)
                    } else if x < -self.thumbstickDeadzone {
                        self.lastThumbstickMoveTime = now
                        self.handleDirection(.left)
                    }
                } else {
                    if y > self.thumbstickDeadzone {
                        self.lastThumbstickMoveTime = now
                        self.handleDirection(.up)
                    } else if y < -self.thumbstickDeadzone {
                        self.lastThumbstickMoveTime = now
                        self.handleDirection(.down)
                    }
                }
            }
        }

        // Action Buttons
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleActionA() }
            }
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleActionB() }
            }
        }
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleActionX() }
            }
        }

        // Shoulder Bumpers & Triggers (Tab switching)
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleShoulderLeft() }
            }
        }
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleShoulderRight() }
            }
        }
        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleShoulderLeft() }
            }
        }
        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleShoulderRight() }
            }
        }

        gamepad.buttonHome?.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleInGameMenuToggle() }
            }
        }
    }

    private func configureMicroGamepad(_ micro: GCMicroGamepad) {
        micro.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleDirection(.left) }
            }
        }
        micro.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleDirection(.right) }
            }
        }
        micro.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleDirection(.up) }
            }
        }
        micro.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleDirection(.down) }
            }
        }
        micro.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleActionA() }
            }
        }
        micro.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in self?.handleActionX() }
            }
        }
    }

    private enum Direction {
        case left, right, up, down
    }

    private func handleDirection(_ dir: Direction) {
        guard isEnabled else { return }
        switch dir {
        case .left:
            onNavigateLeft?()
        case .right:
            onNavigateRight?()
        case .up:
            onNavigateUp?()
        case .down:
            onNavigateDown?()
        }
    }

    private func handleActionA() {
        guard isEnabled else { return }
        onActionA?()
    }

    private func handleActionB() {
        guard isEnabled else { return }
        onActionB?()
    }

    private func handleActionX() {
        guard isEnabled else { return }
        onActionX?()
    }

    private func handleShoulderLeft() {
        guard isEnabled else { return }
        onShoulderLeft?()
    }

    private func handleShoulderRight() {
        guard isEnabled else { return }
        onShoulderRight?()
    }

    private func handleInGameMenuToggle() {
        guard !isEnabled else { return }
        onInGameMenuToggle?()
    }

    private func cleanControllerName(_ name: String) -> String {
        var clean = name
        let removes = ["Wireless Controller", "Controller", "Bluetooth"]
        for word in removes {
            clean = clean.replacingOccurrences(of: word, with: "")
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Controller" : clean
    }
}
