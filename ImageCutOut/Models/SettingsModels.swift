import Foundation

enum BackgroundOption: String, Codable, CaseIterable, Identifiable {
    case transparent
    case white

    var id: String { rawValue }
}

enum ShadowMode: String, Codable, CaseIterable, Identifiable {
    case none
    case soft
    case preserved

    var id: String { rawValue }
}

enum ComparisonMode: String, Codable, CaseIterable, Identifiable {
    case sideBySide
    case overlay
    case difference
    case single

    var id: String { rawValue }
}

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

struct CutoutSettings: Codable, Hashable {
    var edgeQuality: Double
    var featherRadius: Double
    var threshold: Double
    var paddingPercent: Double
    var autoCrop: Bool
    var minObjectSizePercent: Double
    var backgroundOption: BackgroundOption
    var shadowMode: ShadowMode
    var preserveShadowLayer: Bool
    var hairEdgeMode: Bool
    var glassHandlingMode: Bool
    var despeckle: Bool
    var edgeSmoothing: Bool
    var autoWhiteBalance: Bool
    var keepLargestObjectOnly: Bool
    var confidenceThreshold: Double

    static let `default` = CutoutSettings(
        edgeQuality: 0.7,
        featherRadius: 2.0,
        threshold: 0.5,
        paddingPercent: 8,
        autoCrop: true,
        minObjectSizePercent: 2,
        backgroundOption: .transparent,
        shadowMode: .none,
        preserveShadowLayer: false,
        hairEdgeMode: false,
        glassHandlingMode: false,
        despeckle: true,
        edgeSmoothing: true,
        autoWhiteBalance: false,
        keepLargestObjectOnly: true,
        confidenceThreshold: 0.4
    )
}

struct BatchSettings: Codable, Hashable {
    var recursive: Bool
    var concurrencyLimit: Int
    var preserveEXIF: Bool
    var autoResume: Bool
    var retryOnFailure: Bool
    var maxRetries: Int

    static let `default` = BatchSettings(
        recursive: true,
        concurrencyLimit: 3,
        preserveEXIF: false,
        autoResume: true,
        retryOnFailure: true,
        maxRetries: 2
    )
}

struct ExportSizePreset: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var width: Int
    var height: Int
    var maintainAspect: Bool

    init(id: UUID = UUID(), name: String, width: Int, height: Int, maintainAspect: Bool = true) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.maintainAspect = maintainAspect
    }
}

struct ExportSettings: Codable, Hashable {
    var outputFolderBookmarkKey: String?
    var namingRule: String
    var includeOriginals: Bool
    var includePDFReport: Bool
    var exportZipPackage: Bool
    var exportJPG: Bool
    var jpgQuality: Double
    var pngCompression: Double
    var includeAssetsCSV: Bool
    var sizePresets: [ExportSizePreset]
    var includeWatermark: Bool
    var watermarkText: String

    static let `default` = ExportSettings(
        outputFolderBookmarkKey: nil,
        namingRule: "<original_name>__cutout",
        includeOriginals: false,
        includePDFReport: false,
        exportZipPackage: false,
        exportJPG: false,
        jpgQuality: 0.9,
        pngCompression: 0.0,
        includeAssetsCSV: true,
        sizePresets: [
            ExportSizePreset(name: "Thumbnail", width: 512, height: 512, maintainAspect: true),
            ExportSizePreset(name: "Medium", width: 1200, height: 1200, maintainAspect: true),
            ExportSizePreset(name: "Large", width: 2400, height: 2400, maintainAspect: true)
        ],
        includeWatermark: false,
        watermarkText: ""
    )
}

struct QualitySettings: Codable, Hashable {
    var minResolution: Int
    var maxResolution: Int
    var allowedAspectRatios: [Double]
    var edgeSmoothnessThreshold: Double
    var transparencyArtifactsThreshold: Double

    static let `default` = QualitySettings(
        minResolution: 800,
        maxResolution: 5000,
        allowedAspectRatios: [1.0, 4.0 / 5.0, 16.0 / 9.0],
        edgeSmoothnessThreshold: 0.6,
        transparencyArtifactsThreshold: 0.3
    )
}

struct UISettings: Codable, Hashable {
    var theme: ThemeMode
    var comparisonMode: ComparisonMode
    var showOnlyNeedsReview: Bool
    var showOnlyApproved: Bool
    var sortOption: String

    static let `default` = UISettings(
        theme: .system,
        comparisonMode: .sideBySide,
        showOnlyNeedsReview: false,
        showOnlyApproved: false,
        sortOption: "processingTime"
    )
}
