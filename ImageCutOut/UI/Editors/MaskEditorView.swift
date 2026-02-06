import SwiftUI
import AppKit
import CoreImage

enum MaskEditMode: String, CaseIterable, Identifiable {
    case erase
    case restore

    var id: String { rawValue }
}

struct MaskEditorSheet: View {
    @EnvironmentObject private var appState: AppState
    let assetID: UUID?
    @State private var maskImage: CIImage = CIImage(color: .white)
    @State private var brushSize: CGFloat = 20
    @State private var mode: MaskEditMode = .erase
    @State private var undoStack: [CIImage] = []
    @State private var redoStack: [CIImage] = []

    var body: some View {
        VStack(spacing: 12) {
            if let asset = appState.assetStore.asset(for: assetID),
               let outputURL = asset.outputURL {
                HStack {
                    Picker("Mode", selection: $mode) {
                        ForEach(MaskEditMode.allCases) { mode in
                            Text(mode.rawValue.capitalized).tag(mode)
                        }
                    }
                    Slider(value: $brushSize, in: 4...60)
                        .frame(width: 160)
                    Button("Undo") { undo() }
                        .disabled(undoStack.isEmpty)
                        .keyboardShortcut("z", modifiers: .command)
                    Button("Redo") { redo() }
                        .disabled(redoStack.isEmpty)
                        .keyboardShortcut("Z", modifiers: [.command, .shift])
                    Spacer()
                    Button("Apply") { applyMask(asset: asset) }
                        .keyboardShortcut(.defaultAction)
                }
                if let original = NSImage(contentsOf: outputURL) {
                    MaskEditorView(
                        originalImage: original,
                        maskImage: $maskImage,
                        mode: $mode,
                        brushSize: $brushSize,
                        onStroke: { snapshot in
                            undoStack.append(snapshot)
                            redoStack.removeAll()
                        }
                    )
                    .frame(minWidth: 640, minHeight: 420)
                }
            } else {
                Text("Select a processed asset first.")
            }
        }
        .padding(16)
        .onAppear { loadMask() }
        .frame(width: 820, height: 560)
    }

    private func loadMask() {
        guard let asset = appState.assetStore.asset(for: assetID),
              let maskURL = asset.maskURL,
              let ciImage = CIImage(contentsOf: maskURL) else { return }
        maskImage = ciImage
        undoStack.removeAll()
        redoStack.removeAll()
    }

    private func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(maskImage)
        maskImage = last
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(maskImage)
        maskImage = next
    }

    private func applyMask(asset: AssetItem) {
        guard let outputURL = asset.outputURL else { return }
        guard let original = try? ImageProcessing.loadCIImage(from: asset.url) else { return }

        let croppedOriginal = original.cropped(to: maskImage.extent)
        let composited = ImageProcessing.applyMask(image: croppedOriginal, mask: maskImage)
        do {
            try ImageWriter.writePNG(ciImage: composited, to: outputURL, compression: appState.settings.exportSettings.pngCompression)
            if let maskURL = asset.maskURL {
                try? ImageWriter.writePNG(ciImage: maskImage, to: maskURL, compression: 0)
            }
            appState.assetStore.update(assetID: asset.id) { item in
                item.outputURL = outputURL
            }
            BatchOptimizer.shared.recordAdjustment(for: asset, settings: appState.settings.cutoutSettings)
        } catch {
            appState.logStore.log(.error, "Mask apply failed", context: error.localizedDescription)
        }
    }
}

struct MaskEditorView: NSViewRepresentable {
    var originalImage: NSImage
    @Binding var maskImage: CIImage
    @Binding var mode: MaskEditMode
    @Binding var brushSize: CGFloat
    var onStroke: (CIImage) -> Void

    func makeNSView(context: Context) -> MaskEditingView {
        let view = MaskEditingView()
        view.originalImage = originalImage
        view.maskBitmap = MaskBitmap(from: maskImage) ?? MaskBitmap(width: Int(originalImage.size.width), height: Int(originalImage.size.height))
        view.brushSize = brushSize
        view.mode = mode
        view.onStroke = {
            let snapshot = view.maskBitmap?.toCIImage() ?? maskImage
            onStroke(snapshot)
            maskImage = snapshot
        }
        return view
    }

    func updateNSView(_ nsView: MaskEditingView, context: Context) {
        nsView.originalImage = originalImage
        nsView.brushSize = brushSize
        nsView.mode = mode
        nsView.updateMask(from: maskImage)
    }
}

final class MaskEditingView: NSView {
    var originalImage: NSImage?
    var maskBitmap: MaskBitmap?
    var brushSize: CGFloat = 16
    var mode: MaskEditMode = .erase
    var onStroke: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let originalImage = originalImage else { return }
        originalImage.draw(in: bounds)
        if let maskBitmap = maskBitmap, let maskCG = maskBitmap.toCGImage() {
            let maskImage = NSImage(cgImage: maskCG, size: originalImage.size)
            let tinted = NSImage(size: originalImage.size)
            tinted.lockFocus()
            NSColor.systemRed.withAlphaComponent(0.3).setFill()
            NSRect(origin: .zero, size: originalImage.size).fill()
            maskImage.draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1.0)
            tinted.unlockFocus()
            tinted.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }

    override func mouseDown(with event: NSEvent) {
        applyBrush(event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        applyBrush(event: event)
    }

    func updateMask(from image: CIImage) {
        if let bitmap = MaskBitmap(from: image) {
            maskBitmap = bitmap
            needsDisplay = true
        }
    }

    private func applyBrush(event: NSEvent) {
        guard let maskBitmap = maskBitmap else { return }
        let point = convert(event.locationInWindow, from: nil)
        let imagePoint = NSPoint(
            x: point.x / bounds.width * CGFloat(maskBitmap.width),
            y: (1 - point.y / bounds.height) * CGFloat(maskBitmap.height)
        )
        let value: UInt8 = mode == .erase ? 0 : 255
        maskBitmap.applyBrush(at: imagePoint, radius: brushSize, value: value)
        needsDisplay = true
        onStroke?()
    }
}

final class MaskBitmap {
    let width: Int
    let height: Int
    private var data: [UInt8]

    init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
        self.data = Array(repeating: 255, count: self.width * self.height)
    }

    convenience init?(from image: CIImage) {
        guard let cgImage = ImageProcessing.makeCGImage(from: image) else { return nil }
        self.init(width: cgImage.width, height: cgImage.height)
        guard let provider = cgImage.dataProvider, let dataPtr = provider.data else { return }
        let bytes = CFDataGetBytePtr(dataPtr)
        let bytesPerRow = cgImage.bytesPerRow
        let components = cgImage.bitsPerPixel / 8
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * components
                let alpha = bytes?[offset + components - 1] ?? 0
                data[y * width + x] = alpha
            }
        }
    }

    func applyBrush(at point: NSPoint, radius: CGFloat, value: UInt8) {
        let r = Int(radius)
        let centerX = Int(point.x)
        let centerY = Int(point.y)
        for y in max(0, centerY - r)..<min(height, centerY + r) {
            for x in max(0, centerX - r)..<min(width, centerX + r) {
                let dx = x - centerX
                let dy = y - centerY
                if dx * dx + dy * dy <= r * r {
                    data[y * width + x] = value
                }
            }
        }
    }

    func toCGImage() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        return data.withUnsafeBytes { buffer in
            guard let provider = CGDataProvider(data: NSData(bytes: buffer.baseAddress, length: data.count)) else { return nil }
            return CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        }
    }

    func toCIImage() -> CIImage {
        if let cgImage = toCGImage() {
            return CIImage(cgImage: cgImage)
        }
        return CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }
}
