import UIKit

/// Owns navigation for a flow. ViewControllers and ViewModels never push or present screens themselves.
@MainActor
protocol Coordinator: AnyObject {
    func start()
}
