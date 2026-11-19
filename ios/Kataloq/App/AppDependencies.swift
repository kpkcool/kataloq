import Foundation

/// Everything screens need from the outside world, built once at launch.
/// A plain struct: no DI framework. Coordinators pass the protocols on to ViewModels.
@MainActor
struct AppDependencies {
    let productRepository: any ProductRepository
    let enquiryRepository: any EnquiryRepository
    let imageLoader: any ImageLoading

    static func live(configuration: AppConfiguration) -> AppDependencies {
        let apiClient = URLSessionAPIClient(baseURL: configuration.apiBaseURL)
        return AppDependencies(
            productRepository: RemoteProductRepository(apiClient: apiClient),
            enquiryRepository: RemoteEnquiryRepository(apiClient: apiClient),
            imageLoader: URLSessionImageLoader()
        )
    }
}
