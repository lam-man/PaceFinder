/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main tab view controller used in the app.
*/

import UIKit

/// The tab view controller for the app.
class MainTabViewController: UITabBarController {
    
    // MARK: - Initializers
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        setUpTabViewController()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        LaunchDiagnostics.log("MainTabViewController viewDidLoad")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        LaunchDiagnostics.log("MainTabViewController viewDidAppear")
    }
    
    // MARK: - Setup
    
    func setUpTabViewController() {
        viewControllers = [
            createTabNavigationController(
                title: "Activities",
                imageName: "figure.run",
                selectedImageName: "figure.run.circle.fill",
                rootFactory: Self.makeActivitiesRootViewController
            ),
            createTabNavigationController(
                title: "Analytics",
                imageName: "chart.line.uptrend.xyaxis",
                selectedImageName: "chart.line.uptrend.xyaxis.circle.fill",
                rootFactory: Self.makeAnalyticsRootViewController
            ),
            createTabNavigationController(
                title: "Chat",
                imageName: "message",
                selectedImageName: "message.fill",
                rootFactory: Self.makeChatRootViewController
            ),
            createTabNavigationController(
                title: "Profile",
                imageName: "person.circle",
                selectedImageName: "person.circle.fill",
                rootFactory: Self.makeProfileRootViewController
            )
        ]
        
        // Start on the lightest tab so the app becomes interactive before
        // users opt into heavier data-loading surfaces.
        selectedIndex = 3
    }
    
    private func createTabNavigationController(
        title: String,
        imageName: String,
        selectedImageName: String,
        rootFactory: @escaping () -> UIViewController
    ) -> UIViewController {
        let navigationController = DeferredNavigationController(rootFactory: rootFactory)
        navigationController.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: imageName),
            selectedImage: UIImage(systemName: selectedImageName)
        )
        return navigationController
    }
    
    private static func makeActivitiesRootViewController() -> UIViewController {
        if #available(iOS 16.0, *) {
            return RunningActivitiesTableViewController()
        }
        
        return PlaceholderTabViewController(
            titleText: "Activities",
            messageText: "Running activities require iOS 16 or later."
        )
    }
    
    private static func makeAnalyticsRootViewController() -> UIViewController {
        if #available(iOS 16.0, *) {
            return AnalyticsViewController()
        }

        PlaceholderTabViewController(
            titleText: "Analytics",
            messageText: "Pace trends, weekly insights, and training analysis will appear here."
        )
    }
    
    private static func makeChatRootViewController() -> UIViewController {
        PlaceholderTabViewController(
            titleText: "Chat",
            messageText: "Coaching conversations and assistant chat will live here."
        )
    }
    
    private static func makeProfileRootViewController() -> UIViewController {
        WelcomeViewController()
    }
}

private final class DeferredNavigationController: UINavigationController {
    
    private let rootFactory: () -> UIViewController
    private var hasInstalledRootViewController = false
    
    init(rootFactory: @escaping () -> UIViewController) {
        self.rootFactory = rootFactory
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        installRootViewControllerIfNeeded()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        installRootViewControllerIfNeeded()
    }
    
    private func installRootViewControllerIfNeeded() {
        guard !hasInstalledRootViewController else { return }
        
        hasInstalledRootViewController = true
        setViewControllers([rootFactory()], animated: false)
    }
}

private final class PlaceholderTabViewController: UIViewController {
    
    private let titleText: String
    private let messageText: String
    
    init(titleText: String, messageText: String) {
        self.titleText = titleText
        self.messageText = messageText
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = titleText
        view.backgroundColor = .systemBackground
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = messageText
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        label.numberOfLines = 0
        label.textAlignment = .center
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
