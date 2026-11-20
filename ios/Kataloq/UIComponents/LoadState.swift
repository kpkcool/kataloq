import Foundation

/// The states every data-driven screen moves through. ViewModels publish it; ViewControllers render it.
enum LoadState<Value: Equatable>: Equatable {
    case idle
    case loading
    case loaded(Value)
    case empty(message: String)
    case failed(message: String)
}
