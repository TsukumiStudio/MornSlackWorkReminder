// AppIcon.icns を生成する: swift make-icon.swift && iconutil -c icns AppIcon.iconset
// XP風のエラーダイアログ（青いタイトルバー＋赤い×アイコン）をモチーフにする。
import AppKit

func draw(_ s: CGFloat) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s), bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let u = s / 1024
  // macOSアイコンの標準グリッド（824px角、角丸185px）
  let body = NSRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
  let shape = NSBezierPath(roundedRect: body, xRadius: 185 * u, yRadius: 185 * u)
  NSGraphicsContext.current?.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
  shadow.shadowOffset = NSSize(width: 0, height: -10 * u)
  shadow.shadowBlurRadius = 24 * u
  shadow.set()
  NSColor(red: 0.925, green: 0.914, blue: 0.847, alpha: 1).setFill()
  shape.fill()
  NSGraphicsContext.current?.restoreGraphicsState()
  shape.addClip()
  // タイトルバー
  let bar = NSRect(x: body.minX, y: body.maxY - 230 * u, width: body.width, height: 230 * u)
  NSGradient(colors: [
    NSColor(red: 0.21, green: 0.54, blue: 1, alpha: 1),
    NSColor(red: 0, green: 0.33, blue: 0.9, alpha: 1),
    NSColor(red: 0, green: 0.24, blue: 0.71, alpha: 1)
  ])!.draw(in: bar, angle: -90)
  // 閉じるボタン
  let close = NSRect(x: bar.maxX - 190 * u, y: bar.minY + 50 * u, width: 130 * u, height: 130 * u)
  NSGradient(starting: NSColor(red: 0.98, green: 0.69, blue: 0.59, alpha: 1),
             ending: NSColor(red: 0.78, green: 0.19, blue: 0.06, alpha: 1))!
    .draw(in: NSBezierPath(roundedRect: close, xRadius: 22 * u, yRadius: 22 * u), angle: -60)
  cross(in: close.insetBy(dx: 34 * u, dy: 34 * u), width: 18 * u)
  // エラーアイコン
  let circle = NSRect(x: 262 * u, y: 170 * u, width: 500 * u, height: 500 * u)
  NSGradient(colors: [
    NSColor(red: 1, green: 0.54, blue: 0.51, alpha: 1),
    NSColor(red: 0.89, green: 0.15, blue: 0.11, alpha: 1),
    NSColor(red: 0.67, green: 0.06, blue: 0.02, alpha: 1)
  ])!.draw(in: NSBezierPath(ovalIn: circle), relativeCenterPosition: NSPoint(x: -0.4, y: 0.5))
  cross(in: circle.insetBy(dx: 140 * u, dy: 140 * u), width: 62 * u)
  NSGraphicsContext.restoreGraphicsState()
  return rep
}

func cross(in rect: NSRect, width: CGFloat) {
  let path = NSBezierPath()
  path.move(to: NSPoint(x: rect.minX, y: rect.minY)); path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
  path.move(to: NSPoint(x: rect.minX, y: rect.maxY)); path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
  path.lineWidth = width
  path.lineCapStyle = .round
  NSColor.white.setStroke()
  path.stroke()
}

let dir = URL(fileURLWithPath: "AppIcon.iconset")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
    try! draw(CGFloat(base * scale)).representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(name))
  }
}
