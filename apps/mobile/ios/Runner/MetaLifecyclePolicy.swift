import Foundation

enum MetaLifecyclePolicy {
  static func installEligible(
    verified: Bool, production: Bool, bundleID: String,
    originalBuild: String?, currentBuild: String
  ) -> Bool {
    verified && production && bundleID == "com.mycompany.dopmi" &&
      originalBuild == currentBuild && (Int(currentBuild) ?? 0) > 0
  }

  static func context(
    trackingAuthorized: Bool, advertisingID: String, version: String,
    build: String, osVersion: String, bundleID: String, installEligible: Bool
  ) -> [String: Any]? {
    let id = advertisingID.lowercased()
    guard trackingAuthorized, bundleID == "com.mycompany.dopmi",
          id != "00000000-0000-0000-0000-000000000000",
          matches(id, "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"),
          version.count <= 24,
          matches(version, "^[0-9]+(\\.[0-9]+){1,3}([+-][0-9A-Za-z.-]+)?$"),
          matches(osVersion, "^[0-9][0-9A-Za-z._+-]{0,23}$"),
          let number = Int(build), (1...2_100_000_000).contains(number) else {
      return nil
    }
    return [
      "platform": "ios", "package_name": bundleID, "advertising_id": id,
      "tracking_authorized": true, "app_version": version, "app_build": number,
      "os_version": osVersion, "install_eligible": installEligible,
    ]
  }

  private static func matches(_ value: String, _ pattern: String) -> Bool {
    value.range(of: pattern, options: .regularExpression) != nil
  }
}
