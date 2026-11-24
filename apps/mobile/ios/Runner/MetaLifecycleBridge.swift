import AdSupport
import AppTrackingTransparency
import Flutter
import StoreKit
import UIKit

/// No SDK initialization, IDFV, cached identifier, or event queue is used.
final class MetaLifecycleBridge {
  private let channel: FlutterMethodChannel
  private var generation = 0
  private var backgroundObserver: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "io.dopmi.app/meta_lifecycle_measurement", binaryMessenger: messenger
    )
    backgroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.generation += 1 }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "cancel":
        self.generation += 1
        result(nil)
      case "readContext":
        let revision = self.generation
        Task { @MainActor [weak self] in
          guard let self else { result(nil); return }
          result(await self.readContext(revision: revision))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  deinit {
    if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
    channel.setMethodCallHandler(nil)
  }

  @MainActor
  private func current(_ revision: Int) -> Bool {
    revision == generation && UIApplication.shared.applicationState == .active
  }

  @MainActor
  private func readContext(revision: Int) async -> [String: Any]? {
    guard current(revision) else { return nil }
    // Dart reaches this channel only after its saved opt-in and remote gate.
    if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
      _ = await withCheckedContinuation { continuation in
        ATTrackingManager.requestTrackingAuthorization { status in
          continuation.resume(returning: status)
        }
      }
      // ATT dismisses before the app necessarily becomes active. Keep this
      // same consented attempt alive for the active notification, rather than
      // losing it when Dart's resumed callback sees an already-pending run.
      guard await waitUntilActive(revision) else { return nil }
    }
    guard current(revision), ATTrackingManager.trackingAuthorizationStatus == .authorized else {
      return nil
    }
    let bundle = Bundle.main
    guard let bundleID = bundle.bundleIdentifier,
          let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
          let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
      return nil
    }
    var eligible = false
    if #available(iOS 16.0, *) {
      // Sandbox, unverified, unavailable and older original builds are updates
      // or inconclusive: they may Activate but must never fabricate an Install.
      if let transaction = try? await AppTransaction.shared,
         case .verified(let app) = transaction {
        eligible = MetaLifecyclePolicy.installEligible(
          verified: true, production: app.environment == .production, bundleID: app.bundleID,
          originalBuild: app.originalAppVersion, currentBuild: build
        )
      }
    }
    // Recheck ATT and native cancellation after every suspending operation and
    // before actually reading IDFA. No identifier is read for denied ATT.
    guard current(revision), ATTrackingManager.trackingAuthorizationStatus == .authorized else {
      return nil
    }
    return MetaLifecyclePolicy.context(
      trackingAuthorized: true,
      advertisingID: ASIdentifierManager.shared().advertisingIdentifier.uuidString,
      version: version, build: build, osVersion: UIDevice.current.systemVersion,
      bundleID: bundleID, installEligible: eligible
    )
  }

  @MainActor
  private func waitUntilActive(_ revision: Int) async -> Bool {
    if current(revision) { return true }
    guard revision == generation, UIApplication.shared.applicationState != .background else {
      return false
    }
    return await withCheckedContinuation { continuation in
      var completed = false
      var activeObserver: NSObjectProtocol?
      var stoppedObserver: NSObjectProtocol?
      let finish: () -> Void = { [weak self] in
        guard !completed else { return }
        completed = true
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
        if let stoppedObserver { NotificationCenter.default.removeObserver(stoppedObserver) }
        continuation.resume(returning: self?.current(revision) ?? false)
      }
      activeObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
      ) { _ in finish() }
      stoppedObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
      ) { _ in finish() }
      DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: finish)
    }
  }
}
