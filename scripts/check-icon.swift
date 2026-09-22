// SPDX-License-Identifier: GPL-3.0-only
import AppKit

// Use a freshly copied/extracted app: Icon Services caches previews by path.
let image = NSWorkspace.shared.icon(forFile:CommandLine.arguments[1])
image.size = NSSize(width:128,height:128)
let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil, pixelsWide:128, pixelsHigh:128,
    bitsPerSample:8, samplesPerPixel:4, hasAlpha:true, isPlanar:false,
    colorSpaceName:.deviceRGB, bytesPerRow:0, bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
image.draw(in:NSRect(x:0,y:0,width:128,height:128))
NSGraphicsContext.restoreGraphicsState()
// A legacy compatibility frame is pale at these points; our slate tile is dark.
// Sample all four edges to catch the actual system-rendered regression.
for (x,y) in [(64,18),(64,109),(18,64),(109,64)] {
    let color = bitmap.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
    guard color.alphaComponent > 0.8,
          max(color.redComponent,color.greenComponent,color.blueComponent) < 0.65 else {
        fputs("System icon has a pale frame or missing tile at (\(x),\(y)).\n",stderr)
        exit(1)
    }
}
if CommandLine.arguments.count > 2 {
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
}
print("System-rendered icon: slate tile, no pale compatibility frame.")
