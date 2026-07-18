import UIKit

enum PresentationAnchor {
    /// Best available view controller for presenting Google Sign-In.
    @MainActor
    static func rootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
        return window?.rootViewController?.topMostPresented()
    }
}

private extension UIViewController {
    func topMostPresented() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostPresented()
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMostPresented()
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMostPresented()
        }
        return self
    }
}
