import ApplicationServices
import Combine
import Foundation

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var canRunApp = false

    private var timerCancellable: AnyCancellable?
    private var permissionCancellable: AnyCancellable?

    init() {
        refreshAllPermissions()
        startChecking()
    }

    func refreshAllPermissions() {
        let trusted = checkAccessibilityTrust()
        if canRunApp != trusted {
            canRunApp = trusted
        }
    }

    func stopAllChecks() {
        timerCancellable?.cancel()
        timerCancellable = nil
        permissionCancellable?.cancel()
        permissionCancellable = nil
    }

    func requestAccessibilityPermissionAndWait() async {
        _ = checkAccessibilityTrust(prompt: true)
        await waitForAccessibilityPermission()
        refreshAllPermissions()
    }

    private func startChecking() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 2, on: .main, in: .default)
            .autoconnect()
            .merge(with: Just(.now))
            .sink { [weak self] _ in
                self?.refreshAllPermissions()
            }
    }

    private func waitForAccessibilityPermission() async {
        startChecking()
        guard !canRunApp else {
            return
        }
        await withCheckedContinuation { continuation in
            permissionCancellable = $canRunApp.sink { [weak self] canRunApp in
                guard let self else {
                    continuation.resume()
                    return
                }
                if canRunApp {
                    permissionCancellable?.cancel()
                    continuation.resume()
                }
            }
        }
    }

    private func checkAccessibilityTrust(prompt: Bool = false) -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": prompt,
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
