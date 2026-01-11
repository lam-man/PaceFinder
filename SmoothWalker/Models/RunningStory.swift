import Foundation
import CoreLocation

/// A richer payload combining activity metrics with the route for storytelling/visualization
struct RunningStory {
    let activity: RunningActivity
    let route: [CLLocation] // ordered route points; may be empty if no route data
}
