//
//  HeartRateSample.swift
//  PaceFinder
//
//  Created by Codex on 5/20/26.
//  Copyright © 2026 Apple. All rights reserved.
//

import Foundation

struct HeartRateSample: Codable, Hashable {
    let date: Date
    let bpm: Double
}
