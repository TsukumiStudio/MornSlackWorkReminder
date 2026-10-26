import Cocoa
import JavaScriptCore
import ServiceManagement
import WebKit

// 判定ロジック（settings.js / rules.js）と設定画面（popup.*）はWebの部品で書き、
// Swift側はSlackウィンドウの取得・警告ウィンドウ・保存だけを担う。
let slackBundleID = "com.tinyspeck.slackmacgap"
let resources = Bundle.main.resourceURL!
let store = UserDefaults.standard

// MARK: - 保存（設定はchrome.storage.localと同じ形のJSONで1キーに保存する）

func storedSettingsJSON() -> String { store.string(forKey: "settings") ?? "{}" }

func mergeSettings(_ patch: [String: Any]) {
  var settings = (try? JSONSerialization.jsonObject(with: Data(storedSettingsJSON().utf8))) as? [String: Any] ?? [:]
  settings.merge(patch) { $1 }
  if let data = try? JSONSerialization.data(withJSONObject: settings) {
    store.set(String(decoding: data, as: UTF8.self), forKey: "settings")
  }
}

func today() -> String {
  let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
  return "\(c.year!)-\(c.month!)-\(c.day!)"
}

func dailyCount(_ key: String) -> Int {
  let value = store.dictionary(forKey: key)
  return value?["date"] as? String == today() ? max(0, value?["count"] as? Int ?? 0) : 0
}

func setDailyCount(_ key: String, _ count: Int) {
  store.set(["date": today(), "count": count], forKey: key)
}

func json(_ value: [String: Any]) -> String {
  String(decoding: (try? JSONSerialization.data(withJSONObject: value)) ?? Data("{}".utf8), as: UTF8.self)
}

// MARK: - Slackウィンドウ（アクセシビリティAPIでタイトルと位置を読む）

struct SlackWindow {
  let title: String
  let frame: NSRect
  /// 現在のSpaceに見えているSlackウィンドウの番号。最小化・非表示・別Spaceならnil。
  let windowNumber: Int?
  let active: Bool
}

func slackWindow() -> SlackWindow? {
  guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: slackBundleID).first else { return nil }
  let axApp = AXUIElementCreateApplication(app.processIdentifier)
  func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
  }
  guard let windowRef = attribute(axApp, kAXFocusedWindowAttribute) ?? attribute(axApp, kAXMainWindowAttribute) else { return nil }
  let window = windowRef as! AXUIElement
  var origin = CGPoint.zero
  var size = CGSize.zero
  guard let title = attribute(window, kAXTitleAttribute) as? String,
        let position = attribute(window, kAXPositionAttribute),
        let dimensions = attribute(window, kAXSizeAttribute),
        AXValueGetValue(position as! AXValue, .cgPoint, &origin),
        AXValueGetValue(dimensions as! AXValue, .cgSize, &size) else { return nil }
  // AXは左上原点、Cocoaはメイン画面の左下原点。
  let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
  let frame = NSRect(x: origin.x, y: primaryHeight - origin.y - size.height, width: size.width, height: size.height)
  // 警告をこのウィンドウの直上へ重ねるため、画面上のウィンドウ番号を引く（名前を読まないので画面収録の許可は不要）。
  let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
  let candidates = onScreen.filter {
    $0[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier && $0[kCGWindowLayer as String] as? Int == 0
  }
  let bounds = CGRect(origin: origin, size: size)
  let match = candidates.first { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! CFDictionary) == bounds } ?? candidates.first
  return SlackWindow(title: title, frame: frame, windowNumber: match?[kCGWindowNumber as String] as? Int, active: app.isActive)
}

// MARK: - ログ（~/Library/Logs/MornSlackWorkReminder.log と標準エラー）

let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/MornSlackWorkReminder.log")

func log(_ message: String) {
  let line = Data("\(Date()) \(message)\n".utf8)
  FileHandle.standardError.write(line)
  if let handle = try? FileHandle(forWritingTo: logURL) {
    handle.seekToEndOfFile()
    handle.write(line)
    try? handle.close()
  } else {
    try? line.write(to: logURL)
  }
}

// MARK: - アプリ本体

final class OverlayPanel: NSPanel {
  override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, WKNavigationDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply {
  let js = JSContext()!
  let warningTemplate = try! String(contentsOf: resources.appendingPathComponent("warning.html"), encoding: .utf8)
  var statusItem: NSStatusItem!
  var menu = NSMenu()
  let popover = NSPopover()
  var overlay: OverlayPanel?
  var activeChannel = ""
  var enteredAt = Date()
  var nextWarning = Date.distantPast
  var lastState = ""
  let loginItem = NSMenuItem(title: "ログイン時に起動", action: #selector(toggleLoginItem), keyEquivalent: "")
  let accessibilityItem = NSMenuItem(title: "アクセシビリティ権限を許可…", action: #selector(openAccessibility), keyEquivalent: "")

  func applicationDidFinishLaunching(_ notification: Notification) {
    for file in ["settings.js", "rules.js"] {
      js.evaluateScript(try! String(contentsOf: resources.appendingPathComponent(file), encoding: .utf8))
    }
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "仕事しろリマインダー")
    statusItem.button?.action = #selector(statusItemClicked)
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    menu.delegate = self
    menu.addItem(accessibilityItem)
    menu.addItem(loginItem)
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    popover.behavior = .transient

    log("起動しました（アクセシビリティ許可: \(AXIsProcessTrusted())）")
    AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
    // transientのパネルはSpace切替に付いてくるので、0.5秒待たずに判定し直して隠す。
    NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.tick() }
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    accessibilityItem.isHidden = AXIsProcessTrusted()
    loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
  }

  // MARK: 判定

  func tick() {
    guard let slack = slackWindow() else {
      trace("Slackウィンドウを取得できません（アクセシビリティ許可: \(AXIsProcessTrusted())）")
      reset()
      return
    }
    let now = Date()
    let name = js.objectForKeyedSubscript("titleChannel").call(withArguments: [slack.title]).toString() ?? ""
    let elapsed = name == activeChannel ? now.timeIntervalSince(enteredAt) * 1000 : 0
    let result = js.objectForKeyedSubscript("check").call(withArguments: [storedSettingsJSON(), name, elapsed])!
    if let error = result.objectForKeyedSubscript("error"), error.isString {
      trace("設定が不正です: \(error.toString() ?? "")")
      reset()
      return
    }
    let eligible = result.objectForKeyedSubscript("eligible").toBool()
    trace("title=\"\(slack.title)\" name=\"\(name)\" 対象=\(eligible) 警告条件=\(result.objectForKeyedSubscript("warn").toBool()) 表示=\(slack.windowNumber != nil)")
    guard eligible else { reset(); return }
    // 個人チャンネル同士の移動では警告を残す（渡り歩いて逃げられないように）。
    if name != activeChannel {
      activeChannel = name
      enteredAt = now
    }
    guard result.objectForKeyedSubscript("warn").toBool() else {
      removeOverlay()
      return
    }
    if overlay == nil && now >= nextWarning { showWarning() }
    guard let overlay else { return }
    if let number = slack.windowNumber {
      // 常にSlackウィンドウの直上へ。他アプリのウィンドウより手前には出さない。
      overlay.setFrame(slack.frame, display: true)
      overlay.order(.above, relativeTo: number)
      if slack.active && !overlay.isKeyWindow { overlay.makeKey() }
    } else {
      overlay.orderOut(nil)
    }
  }

  // 状態が変わったときだけ記録する。
  func trace(_ state: String) {
    if state != lastState { lastState = state; log(state) }
  }

  func reset() {
    removeOverlay()
    activeChannel = ""
  }

  // MARK: 警告ウィンドウ（Slackウィンドウに重ねる透明パネル）

  func showWarning() {
    let count = dailyCount("dailyWarnings") + 1
    setDailyCount("dailyWarnings", count)
    log("警告を表示します（本日\(count)回目）")
    let html = warningTemplate
      .replacingOccurrences(of: "__COUNT__", with: "\(min(3, (count + 4) / 5))")
      .replacingOccurrences(of: "__REMAINING__", with: "\(max(0, 3 - dailyCount("dailySnoozes")))")
    let config = WKWebViewConfiguration()
    config.userContentController.add(self, name: "dismiss")
    config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "snooze")
    let web = WKWebView(frame: .zero, configuration: config)
    web.setValue(false, forKey: "drawsBackground")
    web.loadHTMLString(html, baseURL: nil)
    // nonactivatingにしてSlackを前面アプリのまま保ち、Escなどのキー入力だけ受け取る。
    let panel = OverlayPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    // transient: Mission Controlに独立したウィンドウとして出さない。
    panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
    panel.contentView = web
    overlay = panel
  }

  // どんな理由で消えても、そこから10秒は次の警告を出さない。
  func removeOverlay() {
    guard let overlay else { return }
    nextWarning = Date().addingTimeInterval(10)
    (overlay.contentView as? WKWebView)?.configuration.userContentController.removeAllScriptMessageHandlers()
    overlay.orderOut(nil)
    self.overlay = nil
  }

  // 最後のウィンドウを閉じた／Esc
  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
    removeOverlay()
  }

  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage,
                             replyHandler: @escaping (Any?, String?) -> Void) {
    switch message.name {
    case "snooze":
      let used = dailyCount("dailySnoozes")
      guard used < 3 else { replyHandler("本日の1分停止は3回すべて使用済みです。", nil); return }
      setDailyCount("dailySnoozes", used + 1)
      mergeSettings(["snoozeUntil": (Date().timeIntervalSince1970 * 1000).rounded() + 60_000])
      replyHandler(nil, nil)
      removeOverlay()
    case "mac":
      handleMac(message.body as? [String: Any] ?? [:]) { replyHandler(json($0), nil) }
    default: // storage: 設定画面の chrome.storage.local 代替
      if let json = message.body as? String,
         let patch = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] {
        mergeSettings(patch)
      }
      replyHandler(storedSettingsJSON(), nil)
    }
  }

  // MARK: メニュー

  // 左クリックで設定のポップオーバー、右クリックでメニュー。
  @objc func statusItemClicked() {
    guard let button = statusItem.button else { return }
    if NSApp.currentEvent?.type == .rightMouseUp {
      popover.performClose(nil)
      statusItem.menu = menu
      button.performClick(nil)
      statusItem.menu = nil
    } else if popover.isShown {
      popover.performClose(nil)
    } else {
      showSettings(from: button)
    }
  }

  func showSettings(from button: NSStatusBarButton) {
    if popover.contentViewController == nil {
      let config = WKWebViewConfiguration()
      let shim = """
        window.chrome = { storage: { local: {
          get: async defaults => ({ ...defaults, ...JSON.parse(await webkit.messageHandlers.storage.postMessage(null)) }),
          set: async values => { await webkit.messageHandlers.storage.postMessage(JSON.stringify(values)); }
        } } };
        """
      config.userContentController.addUserScript(WKUserScript(source: shim, injectionTime: .atDocumentStart, forMainFrameOnly: true))
      config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "storage")
      let macUI = try! String(contentsOf: resources.appendingPathComponent("popup-mac.js"), encoding: .utf8)
      config.userContentController.addUserScript(WKUserScript(source: macUI, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
      config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "mac")
      let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 700), configuration: config)
      web.navigationDelegate = self
      let controller = NSViewController()
      controller.view = web
      popover.contentViewController = controller
      popover.contentSize = web.frame.size
    }
    let web = popover.contentViewController!.view as! WKWebView
    web.loadFileURL(resources.appendingPathComponent("popup.html"), allowingReadAccessTo: resources)
    NSApp.activate()
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
  }

  // 設定画面の中身に合わせてポップオーバーの大きさを決める。
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    webView.evaluateJavaScript("[document.documentElement.scrollWidth, document.documentElement.scrollHeight]") { [weak self] size, _ in
      if let size = size as? [CGFloat], size.count == 2 { self?.popover.contentSize = NSSize(width: size[0], height: size[1]) }
    }
  }

  // 設定画面のMac版専用部品（popup-mac.js）からの依頼。
  func handleMac(_ body: [String: Any], reply: @escaping ([String: Any]) -> Void) {
    switch body["op"] as? String {
    case "info":
      reply(["version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "", "login": SMAppService.mainApp.status == .enabled])
    case "login":
      var result: [String: Any] = [:]
      do {
        if body["value"] as? Bool == true { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
      } catch {
        result["error"] = "ログイン時の起動を変更できませんでした: \(error.localizedDescription)"
      }
      result["login"] = SMAppService.mainApp.status == .enabled
      reply(result)
    case "update":
      update(reply: reply)
    default:
      reply(["error": "不明な操作です。"])
    }
  }

  // Homebrewで入れた前提で brew upgrade し、終わったら新しい版で起動し直す。
  func update(reply: @escaping ([String: Any]) -> Void) {
    guard let brew = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first(where: FileManager.default.isExecutableFile) else {
      NSWorkspace.shared.open(URL(string: "https://github.com/TsukumiStudio/MornSlackWorkReminder/releases/latest")!)
      reply(["error": "Homebrewが見つからないため、リリースページを開きました。"])
      return
    }
    log("brew upgrade を開始します")
    let process = Process()
    // tapの情報が古いと upgrade が「最新版です」で何もしないため、先に update する。
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "\"$0\" update --quiet && \"$0\" upgrade --cask tsukumistudio/tap/mornslackworkreminder", brew]
    // 出力はログへ直接書く（パイプだと出力が多いと詰まる）。
    if let handle = try? FileHandle(forWritingTo: logURL) {
      handle.seekToEndOfFile()
      process.standardOutput = handle
      process.standardError = handle
    }
    process.terminationHandler = { finished in
      DispatchQueue.main.async {
        guard finished.terminationStatus == 0 else {
          log("brew upgrade に失敗しました（終了コード \(finished.terminationStatus)）")
          reply(["error": "更新に失敗しました。~/Library/Logs/MornSlackWorkReminder.log を確認してください。"])
          return
        }
        // 自分が終了してから開かないと、openは起動中の古い版を前面に出すだけになる。
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; open \"$0\"", Bundle.main.bundlePath]
        try? relaunch.run()
        NSApp.terminate(nil)
      }
    }
    do {
      try process.run()
    } catch {
      reply(["error": "brewを起動できませんでした: \(error.localizedDescription)"])
    }
  }

  @objc func toggleLoginItem() {
    do {
      if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
    } catch {
      NSAlert(error: error).runModal()
    }
  }

  @objc func openAccessibility() {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
