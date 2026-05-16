import UIKit

@MainActor
enum AppIconService {
    enum AppIconError: LocalizedError {
        case unsupported
        case system(Error)

        var errorDescription: String? {
            switch self {
            case .unsupported:
                return "This device does not support changing the app icon inside the app."
            case .system(let error):
                return error.localizedDescription
            }
        }
    }

    static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    static var currentAlternateIconName: String? {
        UIApplication.shared.alternateIconName
    }

    static var currentDescriptor: AppIconShopDescriptor {
        AppIconCatalog.descriptor(forAlternateIconName: currentAlternateIconName)
    }

    static func setIcon(_ descriptor: AppIconShopDescriptor, completion: @escaping (Result<Void, AppIconError>) -> Void) {
        guard supportsAlternateIcons else {
            completion(.failure(.unsupported))
            return
        }

        let targetName = descriptor.alternateIconName
        if UIApplication.shared.alternateIconName == targetName {
            completion(.success(()))
            return
        }

        UIApplication.shared.setAlternateIconName(targetName) { error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(.system(error)))
                } else {
                    UserDefaults.standard.set(descriptor.itemId, forKey: AppIconCatalog.selectedIconKey)
                    completion(.success(()))
                }
            }
        }
    }
}
