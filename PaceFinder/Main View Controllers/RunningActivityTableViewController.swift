//
//  RunningActivityTableViewController.swift
//  PaceFinder
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
    private var hasLoadedInitialData = false
    private var isLoadingData = false
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViewController()
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard !hasLoadedInitialData, !isLoadingData else { return }
        requestAuthorizationAndLoadData(forceReload: false)
    }
    
    // MARK: - Setup
    
    private func setupViewController() {
        title = "Activities"
        navigationController?.navigationBar.prefersLargeTitles = true
        
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
    
    private func requestAuthorizationAndLoadData(forceReload: Bool) {
        guard !isLoadingData else { return }
        isLoadingData = true
        
        HealthData.requestRunningDataAccess { [weak self] success in
            guard let self else { return }
            
            if success {
                self.loadRunningData(forceReload: forceReload)
            } else {
                DispatchQueue.main.async {
                    self.isLoadingData = false
                    self.refreshControl?.endRefreshing()
                    print("Running data access denied")
                }
            }
        }
    }
    
    private func loadRunningData(forceReload: Bool) {
        if hasLoadedInitialData && !forceReload {
            DispatchQueue.main.async {
                self.isLoadingData = false
                self.refreshControl?.endRefreshing()
            }
            return
        }
        
        runningDataManager.fetchRunningActivities { [weak self] activities in
            DispatchQueue.main.async {
                guard let self else { return }
                self.runningActivities = activities
                self.hasLoadedInitialData = true
                self.isLoadingData = false
                self.tableView.reloadData()
                self.refreshControl?.endRefreshing()
            }
        }
    }
    
    @objc private func refreshData() {
        requestAuthorizationAndLoadData(forceReload: true)
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
