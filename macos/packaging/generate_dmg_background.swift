import AppKit

let pointsWidth: CGFloat = 660
let pointsHeight: CGFloat = 400
let scale: CGFloat = 2.0
let pixelWidth = Int(pointsWidth * scale)
let pixelHeight = Int(pointsHeight * scale)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelWidth,
    pixelsHigh: pixelHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: pointsWidth, height: pointsHeight)

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    exit(1)
}
NSGraphicsContext.current = context
let cg = context.cgContext

// Cocoa coordinate system has (0,0) at bottom-left!
// Convert Y from top-down (Finder coordinate) to bottom-up (Cocoa coordinate):
func cy(_ topDownY: CGFloat) -> CGFloat {
    return pointsHeight - topDownY
}

// 1. Background gradient
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 1.0).cgColor, // #14171f
    NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.08, alpha: 1.0).cgColor  // #0d0f14
] as CFArray

if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
    cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: pointsHeight), end: CGPoint(x: 0, y: 0), options: [])
}

// 2. Glass container card
let cardRect = CGRect(x: 36, y: 28, width: pointsWidth - 72, height: pointsHeight - 56)
let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 18, yRadius: 18)
NSColor(calibratedWhite: 1.0, alpha: 0.025).setFill()
cardPath.fill()
NSColor(calibratedWhite: 1.0, alpha: 0.07).setStroke()
cardPath.lineWidth = 1.0
cardPath.stroke()

// 3. Drop target zones:
// Left icon center: (175, 195)
// Right icon center: (485, 195)
let leftCenter = CGPoint(x: 175, y: cy(195))
let rightCenter = CGPoint(x: 485, y: cy(195))
let targetSize: CGFloat = 116

for center in [leftCenter, rightCenter] {
    let r = CGRect(x: center.x - targetSize / 2, y: center.y - targetSize / 2, width: targetSize, height: targetSize)
    let p = NSBezierPath(roundedRect: r, xRadius: 22, yRadius: 22)
    NSColor(calibratedWhite: 1.0, alpha: 0.02).setFill()
    p.fill()
    NSColor(calibratedWhite: 1.0, alpha: 0.06).setStroke()
    let dash: [CGFloat] = [5, 5]
    p.setLineDash(dash, count: 2, phase: 0)
    p.lineWidth = 1.2
    p.stroke()
}

// 4. Header at top center
// Logo brackets: [ | ] scaled down to 32x32 at x = pointsWidth/2 - 58, y = cy(60)
let logoSize: CGFloat = 32
let logoX: CGFloat = (pointsWidth / 2) - 58
let logoY: CGFloat = cy(66) - (logoSize / 2)

// Logo badge background
let logoBadgeRect = CGRect(x: logoX - 4, y: logoY - 4, width: logoSize + 8, height: logoSize + 8)
let logoBadge = NSBezierPath(roundedRect: logoBadgeRect, xRadius: 8, yRadius: 8)
NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1.0).setFill()
logoBadge.fill()
NSColor(calibratedWhite: 1.0, alpha: 0.1).setStroke()
logoBadge.lineWidth = 1
logoBadge.stroke()

// Draw brackets inside badge
cg.saveGState()
let scaleLogo = logoSize / 256.0
cg.translateBy(x: logoX, y: logoY)
cg.scaleBy(x: scaleLogo, y: scaleLogo)

let bracketStroke = NSColor(calibratedWhite: 0.95, alpha: 1.0)
bracketStroke.setStroke()

let leftBracket = NSBezierPath()
leftBracket.move(to: CGPoint(x: 74, y: 256 - 44))
leftBracket.line(to: CGPoint(x: 44, y: 256 - 44))
leftBracket.line(to: CGPoint(x: 44, y: 256 - 212))
leftBracket.line(to: CGPoint(x: 74, y: 256 - 212))
leftBracket.lineWidth = 14
leftBracket.lineCapStyle = .round
leftBracket.lineJoinStyle = .round
leftBracket.stroke()

let rightBracket = NSBezierPath()
rightBracket.move(to: CGPoint(x: 182, y: 256 - 44))
rightBracket.line(to: CGPoint(x: 212, y: 256 - 44))
rightBracket.line(to: CGPoint(x: 212, y: 256 - 212))
rightBracket.line(to: CGPoint(x: 182, y: 256 - 212))
rightBracket.lineWidth = 14
rightBracket.lineCapStyle = .round
rightBracket.lineJoinStyle = .round
rightBracket.stroke()

let midLine = NSBezierPath()
midLine.move(to: CGPoint(x: 128, y: 256 - 56))
midLine.line(to: CGPoint(x: 128, y: 256 - 200))
midLine.lineWidth = 14
midLine.lineCapStyle = .round
midLine.stroke()
cg.restoreGState()

// "fima" title text next to logo badge
let title = "fima"
let titleFont = NSFont.systemFont(ofSize: 22, weight: .bold)
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(calibratedWhite: 0.95, alpha: 1.0)
]
(title as NSString).draw(at: CGPoint(x: logoX + logoSize + 12, y: logoY + 1), withAttributes: titleAttrs)

// Subtitle
let subtitle = "Two-panel file manager for desktop"
let subtitleFont = NSFont.systemFont(ofSize: 11.5, weight: .regular)
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: subtitleFont,
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.45)
]
let subSize = (subtitle as NSString).size(withAttributes: subtitleAttrs)
(subtitle as NSString).draw(at: CGPoint(x: (pointsWidth - subSize.width) / 2, y: cy(88)), withAttributes: subtitleAttrs)

// 5. Arrow & Installation instructions between the two icons
let arrowY = cy(195)
let arrowStart: CGFloat = 265
let arrowEnd: CGFloat = 395

// Soft blue glow
cg.saveGState()
let glowPath = NSBezierPath()
glowPath.move(to: CGPoint(x: arrowStart, y: arrowY))
glowPath.line(to: CGPoint(x: arrowEnd - 4, y: arrowY))
NSColor(calibratedRed: 0.22, green: 0.65, blue: 1.0, alpha: 0.22).setStroke()
glowPath.lineWidth = 8
glowPath.stroke()
cg.restoreGState()

// Crisp arrow stem
let arrowLine = NSBezierPath()
arrowLine.move(to: CGPoint(x: arrowStart, y: arrowY))
arrowLine.line(to: CGPoint(x: arrowEnd - 2, y: arrowY))
arrowLine.lineWidth = 2.5
arrowLine.lineCapStyle = .round
NSColor(calibratedRed: 0.35, green: 0.72, blue: 1.0, alpha: 0.85).setStroke()
arrowLine.stroke()

// Arrow head
let head = NSBezierPath()
head.move(to: CGPoint(x: arrowEnd - 12, y: arrowY + 8))
head.line(to: CGPoint(x: arrowEnd, y: arrowY))
head.line(to: CGPoint(x: arrowEnd - 12, y: arrowY - 8))
head.lineWidth = 2.5
head.lineCapStyle = .round
head.lineJoinStyle = .round
NSColor(calibratedRed: 0.35, green: 0.72, blue: 1.0, alpha: 0.85).setStroke()
head.stroke()

// Text above arrow: "Drag to Applications"
let actionText = "Drag to Applications"
let actionFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
let actionAttrs: [NSAttributedString.Key: Any] = [
    .font: actionFont,
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.85)
]
let actionSize = (actionText as NSString).size(withAttributes: actionAttrs)
(actionText as NSString).draw(at: CGPoint(x: (pointsWidth - actionSize.width) / 2, y: arrowY + 16), withAttributes: actionAttrs)

// Hint below arrow: "to install fima"
let hintText = "to install"
let hintFont = NSFont.systemFont(ofSize: 11, weight: .regular)
let hintAttrs: [NSAttributedString.Key: Any] = [
    .font: hintFont,
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.4)
]
let hintSize = (hintText as NSString).size(withAttributes: hintAttrs)
(hintText as NSString).draw(at: CGPoint(x: (pointsWidth - hintSize.width) / 2, y: arrowY - 22), withAttributes: hintAttrs)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    exit(2)
}

let outUrl = URL(fileURLWithPath: "macos/packaging/dmg_background.png")
try pngData.write(to: outUrl)
print("DMG background written to: \(outUrl.path)")
