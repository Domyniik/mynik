// Gera o ícone do Mynik (AppIcon) com CoreGraphics, sem ferramentas externas.
//
// Uso: swift scripts/make-icon.swift Mynik/Resources/Assets.xcassets/AppIcon.appiconset
//
// O desenho: um "M" em forma de linha de gráfico (finanças + "My") sobre o
// gradiente violeta da marca, com um ponto de destaque. O iOS recebe a arte a
// toda a área (o sistema aplica a máscara); o macOS recebe a forma arredondada
// com margem e sombra, como pede a grelha dos ícones do Mac.
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

/// Desenha a arte do ícone no retângulo `rect` (coordenadas com origem em baixo).
func drawArtwork(in ctx: CGContext, rect: CGRect) {
    let s = rect.width / 1024
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        // Coordenadas de desenho com origem em cima, convertidas para o CoreGraphics.
        CGPoint(x: rect.minX + x * s, y: rect.maxY - y * s)
    }

    // Fundo: gradiente diagonal da marca.
    let background = CGGradient(colorsSpace: space, colors: [
        color(0.52, 0.42, 1.00), color(0.36, 0.26, 0.94), color(0.20, 0.11, 0.70),
    ] as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(background, start: p(0, 0), end: p(1024, 1024), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Brilho suave no canto superior esquerdo.
    let glow = CGGradient(colorsSpace: space, colors: [color(1, 1, 1, 0.28), color(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: p(250, 180), startRadius: 0, endCenter: p(250, 180), endRadius: 620 * s, options: [])

    // Linha de base discreta (como num gráfico).
    ctx.setStrokeColor(color(1, 1, 1, 0.22))
    ctx.setLineWidth(14 * s)
    ctx.setLineCap(.round)
    ctx.move(to: p(232, 780))
    ctx.addLine(to: p(792, 780))
    ctx.strokePath()

    // O "M" em linha de gráfico, com sombra.
    let points = [p(262, 690), p(380, 330), p(512, 580), p(644, 330), p(762, 690)]
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18 * s), blur: 40 * s, color: color(0.08, 0.02, 0.35, 0.45))
    ctx.setStrokeColor(color(1, 1, 1))
    ctx.setLineWidth(104 * s)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addLines(between: points)
    ctx.strokePath()
    ctx.restoreGState()

    // Ponto de destaque (menta) no canto: o "agora" do gráfico.
    let dot = p(800, 250)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 50 * s, color: color(0.45, 1.0, 0.85, 0.9))
    ctx.setFillColor(color(0.55, 1.0, 0.86))
    ctx.fillEllipse(in: CGRect(x: dot.x - 44 * s, y: dot.y - 44 * s, width: 88 * s, height: 88 * s))
    ctx.restoreGState()
}

func makeContext(_ size: Int, opaque: Bool = false) -> CGContext {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue)!
    ctx.interpolationQuality = .high
    return ctx
}

func save(_ image: CGImage, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: output).appendingPathComponent(name))
    print("✓ \(name)")
}

// iOS: arte a toda a área, sem transparência.
let ios = makeContext(1024, opaque: true)
drawArtwork(in: ios, rect: CGRect(x: 0, y: 0, width: 1024, height: 1024))
save(ios.makeImage()!, "AppIcon-iOS.png")

// macOS: forma arredondada de 824 pt com margem de 100 pt e sombra.
let mac = makeContext(1024)
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
mac.saveGState()
mac.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0, 0, 0, 0.35))
mac.addPath(shape)
mac.setFillColor(color(0.36, 0.26, 0.94))
mac.fillPath()
mac.restoreGState()
mac.saveGState()
mac.addPath(shape)
mac.clip()
drawArtwork(in: mac, rect: body)
mac.restoreGState()
let macImage = mac.makeImage()!

for (size, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let pixels = size * scale
    let ctx = makeContext(pixels)
    ctx.draw(macImage, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    save(ctx.makeImage()!, "AppIcon-mac-\(size)@\(scale)x.png")
}
