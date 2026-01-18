//
//  RunningActivityTableViewController.swift
//  SmoothWalker
//
//  Created by Wen Lin on 11/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import UIKit
import HealthKit

@available(iOS 16.0, *)
class RunningActivitiesTableViewController: UITableViewController {
    
    private let runningDataManager = RunningDataManager()
    private var runningActivities: [RunningActivity] = []
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViewController()
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Request authorization and load data
        HealthData.requestRunningDataAccess { [weak self] success in
            if success {
                self?.loadRunningData()
            } else {
                print("Running data access denied")
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupViewController() {
        title = "Running Activities"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // Add refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        self.refreshControl = refreshControl
    }
    
    private func setupTableView() {
        tableView.register(RunningActivityTableViewCell.self, forCellReuseIdentifier: RunningActivityTableViewCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.separatorStyle = .singleLine
    }
    
    // MARK: - Data Loading
    
    private func loadRunningData() {
        // For debug: use loadAllRunningData() to test with all activities
        loadLatestRunningData()
    }
    
    /// Load only the latest running activity (recommended for production)
    private func loadLatestRunningData() {
        runningDataManager.fetchLatestRunningActivity { [weak self] activity in
            DispatchQueue.main.async {
                self?.runningActivities = activity.map { [$0] } ?? []
                self?.tableView.reloadData()
                self?.refreshControl?.endRefreshing()
            }
        }
    }
    
    /// Load all running activities (useful for debugging)
    private func loadAllRunningData() {
        runningDataManager.fetchRunningActivities { [weak self] activities in
            DispatchQueue.main.async {
                self?.runningActivities = activities
                self?.tableView.reloadData()
                self?.refreshControl?.endRefreshing()
            }
        }
    }
    
    @objc private func refreshData() {
        loadRunningData()
    }
    
    // MARK: - Table View Data Source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return runningActivities.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: RunningActivityTableViewCell.identifier, for: indexPath) as? RunningActivityTableViewCell else {
            return UITableViewCell()
        }
        
        let activity = runningActivities[indexPath.row]
        cell.configure(with: activity)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let activity = runningActivities[indexPath.row]
        let detailVC = RunningActivityDetailViewController(activity: activity)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
