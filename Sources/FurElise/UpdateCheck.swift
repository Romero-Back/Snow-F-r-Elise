import AppKit
import Sparkle

/// Retry a user-initiated check once when the route to the release feed drops.
/// Sparkle still performs the download, version comparison and signature checks.
final class UpdateCheck: SPUStandardUserDriver {
    private lazy var updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: nil)
    private var retryAvailable = false
    private var retryPending = false

    init() { super.init(hostBundle: .main, delegate: nil) }

    func start() {
        do { try updater.start() }
        catch { NSAlert(error: error).runModal() }
    }

    func check() {
        guard !retryPending else { return }
        retryAvailable = true
        updater.checkForUpdates()
    }

    override func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        var cause: NSError? = error as NSError
        while let current = cause {
            if retryAvailable, current.domain == NSURLErrorDomain,
               [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost,
                NSURLErrorSecureConnectionFailed].contains(current.code) {
                retryAvailable = false
                retryPending = true
                acknowledgement()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self else { return }
                    self.retryPending = false
                    self.updater.checkForUpdates()
                }
                return
            }
            cause = current.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        super.showUpdaterError(error, acknowledgement: acknowledgement)
    }

    override func dismissUpdateInstallation() {
        retryAvailable = false
        super.dismissUpdateInstallation()
    }
}
