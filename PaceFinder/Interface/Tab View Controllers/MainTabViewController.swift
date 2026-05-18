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
        let viewControllers: [UIViewController] = [
            createActivitiesViewController(),
            createAnalyticsViewController(),
            createChatViewController(),
            createProfileViewController()
        ]
        
        self.viewControllers = viewControllers.map {
            UINavigationController(rootViewController: $0)
        }
        
        // Start on the lightest tab so the app becomes interactive before
        // users opt into heavier data-loading surfaces.
        selectedIndex = 3
    }
    
    private func createActivitiesViewController() -> UIViewController {
        if #available(iOS 16.0, *) {
            let viewController = RunningActivitiesTableViewController()
            viewController.tabBarItem = UITabBarItem(title: "Activities",
                                                     image: UIImage(systemName: "figure.run"),
                                                     selectedImage: UIImage(systemName: "figure.run.circle.fill"))
            return viewController
        }
        
        let viewController = PlaceholderTabViewController(
            titleText: "Activities",
            messageText: "Running activities require iOS 16 or later."
        )
        viewController.tabBarItem = UITabBarItem(title: "Activities",
                                                 image: UIImage(systemName: "figure.run"),
                                                 selectedImage: UIImage(systemName: "figure.run.circle.fill"))
        return viewController
    }
    
    private func createAnalyticsViewController() -> UIViewController {
        let viewController = PlaceholderTabViewController(
            titleText: "Analytics",
            messageText: "Pace trends, weekly insights, and training analysis will appear here."
        )
        viewController.tabBarItem = UITabBarItem(title: "Analytics",
                                                 image: UIImage(systemName: "chart.line.uptrend.xyaxis"),
                                                 selectedImage: UIImage(systemName: "chart.line.uptrend.xyaxis.circle.fill"))
        return viewController
    }
    
    private func createChatViewController() -> UIViewController {
        let viewController = PlaceholderTabViewController(
            titleText: "Chat",
            messageText: "Coaching conversations and assistant chat will live here."
        )
        viewController.tabBarItem = UITabBarItem(title: "Chat",
                                                 image: UIImage(systemName: "message"),
                                                 selectedImage: UIImage(systemName: "message.fill"))
        return viewController
    }
    
    private func createProfileViewController() -> UIViewController {
        let viewController = WelcomeViewController()
        
        viewController.tabBarItem = UITabBarItem(title: "Profile",
                                                 image: UIImage(systemName: "person.circle"),
                                                 selectedImage: UIImage(systemName: "person.circle.fill"))
        return viewController
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
