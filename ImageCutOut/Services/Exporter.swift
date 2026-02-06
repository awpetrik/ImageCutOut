import Foundation
import AppKit
import CoreImage

struct Exporter {
    static func export(
        assets: [AssetItem],
        settings: ExportSettings,
        includeOnlyApproved: Bool,
        outputFolder: URL,
        skuMapping: [SKUMapEntry],
        log: LogStore
    ) throws -> URL {
        let exportRoot = outputFolder.appendingPathComponent("ImageCutOut-Export-\(Date().timestampString)")
        let imagesFolder = exportRoot.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)

        var csvRows: [CSVExportRow] = []

        for asset in assets {
            if includeOnlyApproved, asset.approvalStatus != .approved { continue }
            guard let outputURL = asset.outputURL else { continue }

            let baseName = OutputNamer.outputName(for: asset, namingRule: settings.namingRule, skuMapping: skuMapping)
            let targetPNG = imagesFolder.appendingPathComponent(baseName + ".png")
            if FileManager.default.fileExists(atPath: targetPNG.path) {
                try? FileManager.default.removeItem(at: targetPNG)
            }
            if settings.includeWatermark, !settings.watermarkText.isEmpty, let image = NSImage(contentsOf: outputURL) {
                let watermarked = image.addingWatermark(text: settings.watermarkText)
                try ImageWriter.writePNG(image: watermarked, to: targetPNG, compression: settings.pngCompression)
            } else {
                try FileManager.default.copyItem(at: outputURL, to: targetPNG)
            }

            if settings.exportJPG {
                let jpgURL = imagesFolder.appendingPathComponent(baseName + ".jpg")
                if FileManager.default.fileExists(atPath: jpgURL.path) {
                    try? FileManager.default.removeItem(at: jpgURL)
                }
                if let image = NSImage(contentsOf: outputURL) {
                    let final = settings.includeWatermark && !settings.watermarkText.isEmpty ? image.addingWatermark(text: settings.watermarkText) : image
                    try ImageWriter.writeJPG(image: final, to: jpgURL, quality: settings.jpgQuality)
                }
            }

            for preset in settings.sizePresets {
                guard let image = CIImage(contentsOf: outputURL) else { continue }
                var resized = ImageProcessing.resize(
                    image: image,
                    targetSize: CGSize(width: preset.width, height: preset.height),
                    maintainAspect: preset.maintainAspect
                )
                if settings.includeWatermark, !settings.watermarkText.isEmpty,
                   let cgImage = ImageProcessing.makeCGImage(from: resized) {
                    let nsImage = NSImage(cgImage: cgImage, size: .zero).addingWatermark(text: settings.watermarkText)
                    resized = CIImage(data: nsImage.tiffRepresentation ?? Data()) ?? resized
                }
                let variantURL = imagesFolder.appendingPathComponent("\(baseName)_\(preset.name.replacingOccurrences(of: " ", with: "_"))_\(preset.width)x\(preset.height).png")
                if FileManager.default.fileExists(atPath: variantURL.path) {
                    try? FileManager.default.removeItem(at: variantURL)
                }
                try ImageWriter.writePNG(ciImage: resized, to: variantURL, compression: settings.pngCompression)
            }

            let metadata = asset.metadata
            let row = CSVExportRow(
                filename: baseName + ".png",
                sku: metadata.sku ?? "",
                name: metadata.productName ?? asset.fileName,
                brand: metadata.brand ?? "",
                category: metadata.category ?? "",
                tags: metadata.tags.joined(separator: "|"),
                generatedAt: ISO8601DateFormatter().string(from: metadata.generatedAt ?? Date())
            )
            csvRows.append(row)
        }

        if settings.includeAssetsCSV {
            let csvText = CSVExporter.export(rows: csvRows)
            let csvURL = exportRoot.appendingPathComponent("assets.csv")
            try csvText.write(to: csvURL, atomically: true, encoding: .utf8)
        }

        if settings.includePDFReport {
            let pdfURL = exportRoot.appendingPathComponent("report.pdf")
            let report = ReportBuilder.buildReport(assets: assets)
            try report.write(to: pdfURL)
        }

        if settings.includeOriginals {
            let originalsFolder = exportRoot.appendingPathComponent("originals", isDirectory: true)
            try FileManager.default.createDirectory(at: originalsFolder, withIntermediateDirectories: true)
            for asset in assets {
                let destination = originalsFolder.appendingPathComponent(asset.url.lastPathComponent)
                if FileManager.default.fileExists(atPath: destination.path) { continue }
                try? FileManager.default.copyItem(at: asset.url, to: destination)
            }
        }

        log.log(.info, "Export completed", context: exportRoot.path)

        if settings.exportZipPackage {
            return try ZipExporter.zipFolder(exportRoot)
        }

        return exportRoot
    }
}

struct OutputNamer {
    static func outputName(for asset: AssetItem, namingRule: String, skuMapping: [SKUMapEntry]) -> String {
        var result = namingRule
        let mapping = SKUMapper.match(for: asset.fileName, mapping: skuMapping)
        result = result.replacingOccurrences(of: "<original_name>", with: asset.fileName)
        result = result.replacingOccurrences(of: "<SKU>", with: asset.metadata.sku ?? mapping?.sku ?? "")
        result = result.replacingOccurrences(of: "<Brand>", with: asset.metadata.brand ?? mapping?.brand ?? "")
        result = result.replacingOccurrences(of: "<Variant>", with: asset.metadata.variant ?? mapping?.variant ?? "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ImageWriter {
    static func writePNG(ciImage: CIImage, to url: URL, compression: Double) throws {
        guard let cgImage = ImageProcessing.makeCGImage(from: ciImage) else { return }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let data = bitmapRep.representation(using: .png, properties: [.compressionFactor: compression])
        try data?.write(to: url)
    }

    static func writePNG(image: NSImage, to url: URL, compression: Double) throws {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return }
        let data = bitmap.representation(using: .png, properties: [.compressionFactor: compression])
        try data?.write(to: url)
    }

    static func writeJPG(image: NSImage, to url: URL, quality: Double) throws {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return }
        let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        try data?.write(to: url)
    }
}

struct ZipExporter {
    static func zipFolder(_ folder: URL) throws -> URL {
        let zipURL = folder.deletingLastPathComponent().appendingPathComponent(folder.lastPathComponent + ".zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = folder.deletingLastPathComponent()
        process.arguments = ["-r", zipURL.lastPathComponent, folder.lastPathComponent]
        try process.run()
        process.waitUntilExit()
        return zipURL
    }
}

struct ReportBuilder {
    static func buildReport(assets: [AssetItem]) -> Data {
        let header = "ImageCutOut Report\n\n"
        let lines = assets.map { asset in
            "\(asset.fileName) - \(asset.status.rawValue) - \(asset.approvalStatus.rawValue)"
        }
        let content = header + lines.joined(separator: "\n")
        let attributed = NSAttributedString(string: content, attributes: [.font: NSFont.systemFont(ofSize: 12)])

        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter @ 72 dpi
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        ctx.beginPDFPage(nil)
        let graphicsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        attributed.draw(in: mediaBox.insetBy(dx: 36, dy: 36))
        NSGraphicsContext.restoreGraphicsState()
        ctx.endPDFPage()
        ctx.closePDF()

        return data as Data
    }
}

private extension Date {
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: self)
    }
}
