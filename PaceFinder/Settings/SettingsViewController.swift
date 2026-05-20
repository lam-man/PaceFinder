import UIKit

final class SettingsViewController: UITableViewController {

    private enum Row: Int, CaseIterable {
        case age
        case hrMax
    }

    init() {
        super.init(style: .insetGrouped)
        title = "Settings"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Heart Rate Settings"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "SettingsCell")
        guard let row = Row(rawValue: indexPath.row) else { return cell }

        switch row {
        case .age:
            cell.textLabel?.text = "Age"
            let age = UserDefaults.standard.double(forKey: "userAge")
            cell.detailTextLabel?.text = age > 0 ? "\(Int(age))" : "Not set"
        case .hrMax:
            cell.textLabel?.text = "Max Heart Rate"
            let stored = UserDefaults.standard.double(forKey: "userHRmax")
            if stored > 0 {
                cell.detailTextLabel?.text = "\(Int(stored)) bpm (custom)"
            } else {
                let age = UserDefaults.standard.double(forKey: "userAge")
                let effectiveAge = age > 0 ? age : 30
                cell.detailTextLabel?.text = "\(Int(220 - effectiveAge)) bpm (220 − age)"
            }
        }

        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = Row(rawValue: indexPath.row) else { return }

        switch row {
        case .age:
            presentEditAlert(title: "Age", key: "userAge", placeholder: "Enter age (e.g. 30)")
        case .hrMax:
            presentEditAlert(title: "Max Heart Rate", key: "userHRmax", placeholder: "Enter max HR (e.g. 185), or 0 to use 220−age")
        }
    }

    private func presentEditAlert(title: String, key: String, placeholder: String) {
        let alert = UIAlertController(title: "Edit \(title)", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            let existing = UserDefaults.standard.double(forKey: key)
            tf.placeholder = placeholder
            tf.keyboardType = .numberPad
            if existing > 0 { tf.text = "\(Int(existing))" }
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            if let text = alert.textFields?.first?.text, let value = Double(text) {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
            self?.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
