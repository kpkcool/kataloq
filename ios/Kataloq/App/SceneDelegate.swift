import UIKit

/// Builds the window in code (no storyboard) and hands control to the AppCoordinator.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    /// The scene owns the root coordinator for the app's lifetime.
    private var appCoordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.tintColor = Theme.Color.accent
        self.window = window

        // Unit tests run inside the app. Don't start the real UI or hit the network while they run.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            window.rootViewController = UIViewController()
            window.makeKeyAndVisible()
            return
        }

        let navigationController = UINavigationController()
        navigationController.navigationBar.prefersLargeTitles = true

        let coordinator = AppCoordinator(
            navigationController: navigationController,
            dependencies: .live(configuration: .load())
        )
        appCoordinator = coordinator

        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        coordinator.start()
    }
}
