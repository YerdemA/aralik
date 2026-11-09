import AVFoundation
import CryptoKit
import Flutter
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KabacaPlugin") {
      KabacaPlugin.register(with: registrar)
    }
  }
}

/// The app's own platform side, the iOS twin of MainActivity.kt: sound
/// effects (lib/data/sound.dart), invite links (lib/data/invite_links.dart),
/// the store page (lib/data/store_link.dart), the leaderboard's device key
/// (lib/data/device_key.dart) and the system proxy (lib/data/net.dart).
/// Small method channels, so no package is needed.
final class KabacaPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private var links: FlutterMethodChannel?

  // The link the app was opened with, kept until Dart asks for it once;
  // links arriving after that are sent as they come.
  private var initialLink: String?
  private var initialAsked = false

  // A few players per sound, so a sound can overlap itself (fast taps).
  private var players: [String: [AVAudioPlayer]] = [:]
  private var sessionReady = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = KabacaPlugin()
    let messenger = registrar.messenger()

    let links = FlutterMethodChannel(name: "com.yerdema.kabaca/links", binaryMessenger: messenger)
    links.setMethodCallHandler { [weak plugin] call, result in
      guard let plugin, call.method == "initial" else {
        result(FlutterMethodNotImplemented)
        return
      }
      plugin.initialAsked = true
      result(plugin.initialLink)
      plugin.initialLink = nil
    }
    plugin.links = links

    FlutterMethodChannel(name: "com.yerdema.kabaca/sound", binaryMessenger: messenger)
      .setMethodCallHandler { [weak plugin] call, result in
        guard let plugin else { return result(false) }
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "load":
          guard let name = args?["name"] as? String,
            let bytes = args?["bytes"] as? FlutterStandardTypedData
          else { return result(false) }
          result(plugin.loadSound(name, bytes.data))
        case "play":
          result(plugin.playSound(args?["name"] as? String ?? ""))
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    FlutterMethodChannel(name: "com.yerdema.kabaca/store", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "openStore" else { return result(FlutterMethodNotImplemented) }
        let id = (call.arguments as? [String: Any])?["appStoreId"] as? String
        openStore(appStoreId: id, result: result)
      }

    FlutterMethodChannel(name: "com.yerdema.kabaca/device", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "deviceKey" else { return result(FlutterMethodNotImplemented) }
        result(deviceKey())
      }

    FlutterMethodChannel(name: "com.yerdema.kabaca/net", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "proxy" else { return result(FlutterMethodNotImplemented) }
        result(systemProxy())
      }

    registrar.addSceneDelegate(plugin)
    registrar.publish(plugin)
  }

  // MARK: Invite links (universal links: kabaca.app/d/KOD, /t/KOD)

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let activity = connectionOptions?.userActivities.first(where: isWebLink) else {
      return false
    }
    received(activity.webpageURL?.absoluteString)
    return true
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    guard isWebLink(userActivity) else { return false }
    received(userActivity.webpageURL?.absoluteString)
    return true
  }

  private func isWebLink(_ activity: NSUserActivity) -> Bool {
    activity.activityType == NSUserActivityTypeBrowsingWeb && activity.webpageURL != nil
  }

  private func received(_ link: String?) {
    guard let link else { return }
    if initialAsked {
      links?.invokeMethod("open", arguments: link)
    } else {
      initialLink = link
    }
  }

  // MARK: Sound effects (IMA4 CAF from assets/sounds/ios/)

  private func loadSound(_ name: String, _ data: Data) -> Bool {
    if players[name] != nil { return true }
    if !sessionReady {
      // Ambient: mixes with the player's music and is silent when the
      // phone's ring/silent switch is on silent, like Android's ringer check.
      try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
      sessionReady = true
    }
    var list: [AVAudioPlayer] = []
    for _ in 0..<3 {
      guard let player = try? AVAudioPlayer(data: data) else { break }
      player.volume = 0.7
      player.prepareToPlay()
      list.append(player)
    }
    if list.isEmpty { return false }
    players[name] = list
    return true
  }

  private func playSound(_ name: String) -> Bool {
    guard let list = players[name] else { return false }
    let player = list.first(where: { !$0.isPlaying }) ?? list[0]
    player.currentTime = 0
    return player.play()
  }

  // MARK: Store page (the update notice)

  private static func openStore(appStoreId: String?, result: @escaping FlutterResult) {
    guard let id = appStoreId, !id.isEmpty, id.allSatisfy(\.isNumber),
      let url = URL(string: "itms-apps://apps.apple.com/app/id\(id)")
    else { return result(false) }
    UIApplication.shared.open(url, options: [:]) { opened in
      if opened { return result(true) }
      guard let web = URL(string: "https://apps.apple.com/app/id\(id)") else { return result(false) }
      UIApplication.shared.open(web, options: [:]) { result($0) }
    }
  }

  // MARK: Device key (one leaderboard account per device)

  /// SHA-256 (hex) of a random id kept in this device's keychain. The
  /// keychain outlives deleting and reinstalling the app, like Android's
  /// ANDROID_ID; "ThisDeviceOnly" keeps it out of backups, so a new phone
  /// gets a new id. The id itself never leaves the phone.
  private static func deviceKey() -> String? {
    let base: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.yerdema.kabaca.device",
      kSecAttrAccount as String: "id",
    ]
    var query = base
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    var id: String?
    if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    {
      id = String(data: data, encoding: .utf8)
    }
    if id == nil || id!.isEmpty {
      let fresh = UUID().uuidString
      var add = base
      add[kSecValueData as String] = Data(fresh.utf8)
      add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { return nil }
      id = fresh
    }
    let digest = SHA256.hash(data: Data("kabaca-device:\(id!)".utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  // MARK: System proxy (dart:io does not read it)

  /// "host:port" of the HTTPS (else HTTP) proxy in use, or nil.
  private static func systemProxy() -> String? {
    guard let unmanaged = CFNetworkCopySystemProxySettings(),
      let settings = unmanaged.takeRetainedValue() as? [String: Any]
    else { return nil }
    for kind in ["HTTPS", "HTTP"] {
      guard (settings["\(kind)Enable"] as? Int) == 1,
        let host = settings["\(kind)Proxy"] as? String, !host.isEmpty,
        let port = settings["\(kind)Port"] as? Int, port > 0
      else { continue }
      return "\(host):\(port)"
    }
    return nil
  }
}
