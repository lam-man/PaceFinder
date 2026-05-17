/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main tab view controller used in the app.
*/

import UIKit

/// The tab view controller for the app. The controller will load the last viewed view controller on `viewDidLoad`.
class MainTabViewController: UITabBarController {
    
    // MARK: - Initializers
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        setUpTabViewController()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        
        delegate = self
        selectedIndex = safeSelectedIndex()
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
        let viewController = MobilityChartDataViewController()
        viewController.title = "Analytics"
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
    
    // MARK: - View Persistence
    
    private static let lastViewControllerViewed = "LastViewControllerViewed"
    private var userDefaults = UserDefaults.standard
    
    private func safeSelectedIndex() -> Int {
        let savedIndex = (userDefaults.object(forKey: Self.lastViewControllerViewed) as? Int) ?? 0
        let lastIndex = max((viewControllers?.count ?? 1) - 1, 0)
        return min(savedIndex, lastIndex)
    }
}

// MARK: - UITabBarControllerDelegate
extension MainTabViewController: UITabBarControllerDelegate {
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let index = tabBar.items?.firstIndex(of: item) else { return }
        
        setLastViewedViewControllerIndex(index)
    }
    
    private func setLastViewedViewControllerIndex(_ index: Int) {
        userDefaults.set(index, forKey: Self.lastViewControllerViewed)
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
