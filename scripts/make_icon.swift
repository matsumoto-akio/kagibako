// AppIcon の元画像(1024x1024 PNG)を生成する。
// 使い方: swift scripts/make_icon.swift <出力先.png>
//
// デザイン素材を外部に持たないので、SF Symbols の鍵記号をコードで描く。
// 差し替えたくなったら docs/assets/AppIcon.icns を上書きすればよい。
import AppKit

let canvasSize: CGFloat = 1024
// macOS Big Sur 以降のアイコンは 1024 のキャンバスに 824 角の角丸を置く。
let plateSize: CGFloat = 824
let cornerRadius: CGFloat = 185
let symbolRatio: CGFloat = 0.52

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("使い方: swift scripts/make_icon.swift <出力先.png>\n".utf8))
    exit(1)
}
let outputPath = CommandLine.arguments[1]

let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    FileHandle.standardError.write(Data("描画コンテキストを取得できませんでした\n".utf8))
    exit(1)
}

let plateRect = NSRect(
    x: (canvasSize - plateSize) / 2,
    y: (canvasSize - plateSize) / 2,
    width: plateSize,
    height: plateSize
)
let plate = NSBezierPath(roundedRect: plateRect, xRadius: cornerRadius, yRadius: cornerRadius)

// 濃紺→藍のグラデーション。「金庫・堅牢」の印象を出しつつ警告色は避ける。
context.saveGState()
plate.addClip()
let gradient = NSGradient(
    colors: [
        NSColor(srgbRed: 0.13, green: 0.20, blue: 0.42, alpha: 1),
        NSColor(srgbRed: 0.05, green: 0.09, blue: 0.22, alpha: 1),
    ]
)
gradient?.draw(in: plateRect, angle: -90)
context.restoreGState()

let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: plateSize * symbolRatio, weight: .semibold)
guard let symbol = NSImage(systemSymbolName: "key.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfiguration) else {
    FileHandle.standardError.write(Data("SF Symbols の key.fill を取得できませんでした\n".utf8))
    exit(1)
}

let tinted = NSImage(size: symbol.size)
tinted.lockFocus()
NSColor.white.set()
NSRect(origin: .zero, size: symbol.size).fill()
symbol.draw(at: .zero, from: NSRect(origin: .zero, size: symbol.size), operation: .destinationIn, fraction: 1)
tinted.unlockFocus()

let symbolRect = NSRect(
    x: (canvasSize - tinted.size.width) / 2,
    y: (canvasSize - tinted.size.height) / 2,
    width: tinted.size.width,
    height: tinted.size.height
)
tinted.draw(in: symbolRect)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("PNG への変換に失敗しました\n".utf8))
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("生成: \(outputPath)")
} catch {
    FileHandle.standardError.write(Data("書き出しに失敗しました: \(error)\n".utf8))
    exit(1)
}
