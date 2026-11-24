import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testMetaInstallNeedsVerifiedProductionMatchingOriginalBuild() {
    XCTAssertTrue(MetaLifecyclePolicy.installEligible(
      verified: true, production: true, bundleID: "com.mycompany.dopmi",
      originalBuild: "444", currentBuild: "444"
    ))
    for invalid in [
      (verified: false, production: true, bundle: "com.mycompany.dopmi", original: "444"),
      (verified: true, production: false, bundle: "com.mycompany.dopmi", original: "444"),
      (verified: true, production: true, bundle: "com.other.app", original: "444"),
      (verified: true, production: true, bundle: "com.mycompany.dopmi", original: "443"),
      (verified: true, production: false, bundle: "com.mycompany.dopmi", original: "1.0"),
    ] {
      XCTAssertFalse(MetaLifecyclePolicy.installEligible(
        verified: invalid.verified, production: invalid.production, bundleID: invalid.bundle,
        originalBuild: invalid.original, currentBuild: "444"
      ))
    }
  }

  func testMetaContextRequiresATTAndARealIdentifier() {
    let id = "81000000-0000-4000-8000-000000000001"
    XCTAssertNotNil(MetaLifecyclePolicy.context(
      trackingAuthorized: true, advertisingID: id, version: "2.3.13", build: "444",
      osVersion: "26.1", bundleID: "com.mycompany.dopmi", installEligible: false
    ))
    XCTAssertNil(MetaLifecyclePolicy.context(
      trackingAuthorized: false, advertisingID: id, version: "2.3.13", build: "444",
      osVersion: "26.1", bundleID: "com.mycompany.dopmi", installEligible: true
    ))
    XCTAssertNil(MetaLifecyclePolicy.context(
      trackingAuthorized: true, advertisingID: "00000000-0000-0000-0000-000000000000",
      version: "2.3.13", build: "444", osVersion: "26.1",
      bundleID: "com.mycompany.dopmi", installEligible: true
    ))
  }

}
