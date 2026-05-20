import SwiftUI

@available(iOS 13.0, *)
final class UIHostingControllerBridge<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
}
