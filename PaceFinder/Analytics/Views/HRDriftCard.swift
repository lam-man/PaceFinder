import UIKit

final class HRDriftCard: UIView {

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .preferredFont(forTextStyle: .caption1)
        l.textColor = .secondaryLabel
        l.text = "HR Drift"
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .preferredFont(forTextStyle: .title2)
        return l
    }()

    init(driftPercent: Double?) {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        clipsToBounds = true

        if let drift = driftPercent {
            valueLabel.text = String(format: "%.1f%%", drift)
            valueLabel.textColor = drift < 5 ? .systemGreen : drift < 10 ? .systemOrange : .systemRed
        } else {
            valueLabel.text = "Requires per-sample heart rate data"
            valueLabel.font = .preferredFont(forTextStyle: .caption1)
            valueLabel.textColor = .secondaryLabel
        }

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 4
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
