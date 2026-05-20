/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The scene delegate.
*/

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var isMinimumDurationElapsed = false
    private var isSplashAnimationComplete = false
    private var isMainTabReady = false
    private var hasCommittedRootSwap = false
    private weak var splashViewController: LaunchSplashViewController?
    private weak var mainTabViewController: MainTabViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        LaunchDiagnostics.log("scene(_:willConnectTo:) started")

        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        let splash = LaunchSplashViewController()
        let mainTab = MainTabViewController()
        splash.embedMainViewController(mainTab)
        splash.onAnimationComplete = { [weak self] in
            self?.isSplashAnimationComplete = true
            self?.attemptRootSwap(force: false)
        }
        mainTab.onFirstAppear = { [weak self] in
            LaunchDiagnostics.log("MainTab ready signal received")
            self?.isMainTabReady = true
            self?.attemptRootSwap(force: false)
        }

        splashViewController = splash
        mainTabViewController = mainTab
        window.rootViewController = splash
        
        self.window = window
        
        window.makeKeyAndVisible()
        LaunchDiagnostics.log("window.makeKeyAndVisible() finished")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.isMinimumDurationElapsed = true
            self?.attemptRootSwap(force: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.attemptRootSwap(force: true)
        }

        DispatchQueue.main.async {
            LaunchDiagnostics.log("main queue was available after initial window setup")
        }
    }

    private func attemptRootSwap(force: Bool) {
        guard !hasCommittedRootSwap else { return }
        guard let window, let splashViewController, let mainTabViewController else { return }
        guard window.rootViewController === splashViewController else { return }

        if !force {
            guard isMinimumDurationElapsed, isSplashAnimationComplete, isMainTabReady else { return }
        }

        hasCommittedRootSwap = true
        splashViewController.detachEmbeddedMainViewController()

        UIView.transition(with: window, duration: 0.30, options: .transitionCrossDissolve) {
            window.rootViewController = mainTabViewController
        } completion: { _ in
            LaunchDiagnostics.log("Root swap committed")
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

}
