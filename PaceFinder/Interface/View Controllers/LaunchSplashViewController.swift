import UIKit

final class LaunchSplashViewController: UIViewController {

    var onAnimationComplete: (() -> Void)?

    private let symbolPointSize: CGFloat = 120
    private var hasStartedAnimation = false
    private weak var embeddedMainViewController: UIViewController?

    private lazy var iconView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        let imageView = UIImageView(image: UIImage(systemName: "figure.run", withConfiguration: configuration))
        imageView.tintColor = .label
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.alpha = 0
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setUpIconView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasStartedAnimation else { return }
        hasStartedAnimation = true
        LaunchDiagnostics.log("Launch splash started")
        runAnimation()
    }

    func embedMainViewController(_ viewController: UIViewController) {
        guard embeddedMainViewController == nil else { return }

        embeddedMainViewController = viewController
        addChild(viewController)
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.alpha = 0
        view.insertSubview(viewController.view, at: 0)

        NSLayoutConstraint.activate([
            viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        viewController.didMove(toParent: self)
    }

    func detachEmbeddedMainViewController() {
        guard let embeddedMainViewController else { return }
        embeddedMainViewController.view.alpha = 1
        embeddedMainViewController.willMove(toParent: nil)
        embeddedMainViewController.view.removeFromSuperview()
        embeddedMainViewController.removeFromParent()
        self.embeddedMainViewController = nil
    }

    private func setUpIconView() {
        view.addSubview(iconView)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: symbolPointSize),
            iconView.heightAnchor.constraint(equalToConstant: symbolPointSize)
        ])
    }

    private func runAnimation() {
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut]) { [weak self] in
            self?.iconView.alpha = 1
        } completion: { [weak self] _ in
            self?.runBreathingIfNeeded()
        }
    }

    private func runBreathingIfNeeded() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            runFadeOut()
            return
        }

        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut]) { [weak self] in
            self?.iconView.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        } completion: { [weak self] _ in
            UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut]) {
                self?.iconView.transform = .identity
            } completion: { [weak self] _ in
                self?.runFadeOut()
            }
        }
    }

    private func runFadeOut() {
        UIView.animate(withDuration: 0.30, delay: 0, options: [.curveEaseInOut]) { [weak self] in
            self?.iconView.alpha = 0
        } completion: { [weak self] _ in
            LaunchDiagnostics.log("Launch splash animation ended")
            self?.onAnimationComplete?()
        }
    }
}
