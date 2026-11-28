#if os(iOS)
import Foundation
import UIKit

/**
Helper class to produce device information attributes

The values appended to the attribute come primarily from the Bundle or UIDevice API

AppInfo contains:
- version: the version name of the app.
- build: the version code of the app.
- namespace: the package name of the app.

DeviceInfo contains:
- manufacturer: the manufacturer of the device.
- model: the model of the device.
- type: the type of the device.

OsInfo contains:
- name: the name of the OS.
- version: the version of the OS.

Locale contains:
- locale: the locale of the device.
- preferred_languages: the preferred languages of the device.

The attributes are only updated when the class is initialized and then static.
*/
public class DeviceInfoAttributeDecorator {
    private let staticAttribute: Value

    /// - Parameters:
    ///   - withDeviceInfo: If true, includes device hardware information
    ///   - withAppInfo: If true, includes application metadata
    ///   - withOsInfo: If true, includes operating system information
    ///   - withLocale: If true, includes locale and language preferences
    public init(
        withDeviceInfo: Bool = false,
        withAppInfo: Bool = false,
        withOsInfo: Bool = false,
        withLocale: Bool = false
    ) {
        var attributes: [String: Value] = [:]

        if withDeviceInfo {
            let device = UIDevice.current

            attributes["device"] = .structure([
                "manufacturer": .string("Apple"),
                "model": .string(Self.getDeviceModelIdentifier()),
                "type": .string(device.model),
            ])
        }

        if withAppInfo {
            let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let currentBuild: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
            let bundleId = Bundle.main.bundleIdentifier ?? ""

            attributes["app"] = .structure([
                "version": .string(currentVersion),
                "build": .string(currentBuild),
                "namespace": .string(bundleId),
            ])
        }

        if withOsInfo {
            let device = UIDevice.current

            attributes["os"] = .structure([
                "name": .string(device.systemName),
                "version": .string(device.systemVersion),
            ])
        }

        if withLocale {
            let locale = Locale.current
            let preferredLanguages = Locale.preferredLanguages

            // Top level fields
            attributes["locale"] = .string(locale.identifier) // Locale identifier (e.g., "en_US")
            attributes["preferred_languages"] = .list(preferredLanguages.map { lang in
                .string(lang)
            })
        }

        self.staticAttribute = .structure(attributes)
    }

    /// Returns an attribute where values are decorated (appended) according to the configuration of the `DeviceInfoAttributeDecorator`.
    /// Values provided in the `attributes` parameter take precedence over those appended by this class.
    public func decorated(attributes attributesToDecorate: [String: Value]) -> [String: Value] {
        var result = self.staticAttribute.asStructure() ?? [:]
        attributesToDecorate.forEach { (key: String, value: Value) in
            result[key] = value
        }
        return result
    }


    private static func getDeviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children
            .compactMap { element in element.value as? Int8 }
            .filter { $0 != 0 }
            .map {
                Character(UnicodeScalar(UInt8($0)))
            }
        return String(identifier)
    }
}
#endif
