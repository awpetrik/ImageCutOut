import Foundation
import AppKit

enum AssetStatus: String, Codable, CaseIterable {
    case pending
    case processing
    case done
    case failed
    case needsReview
    case paused
}

enum AssetApprovalStatus: String, Codable, CaseIterable {
    case pending
    case approved
    case rejected
    case flagged
}

struct AssetMetadata: Codable, Hashable {
    var sku: String?
    var productName: String?
    var brand: String?
    var variant: String?
    var size: String?
    var category: String?
    var color: String?
    var tags: [String]
    var generatedAt: Date?

    init(
        sku: String? = nil,
        productName: String? = nil,
        brand: String? = nil,
        variant: String? = nil,
        size: String? = nil,
        category: String? = nil,
        color: String? = nil,
        tags: [String] = [],
        generatedAt: Date? = nil
    ) {
        self.sku = sku
        self.productName = productName
        self.brand = brand
        self.variant = variant
        self.size = size
        self.category = category
        self.color = color
        self.tags = tags
        self.generatedAt = generatedAt
    }
}

struct AssetQualityMetrics: Codable, Hashable {
    var edgeSmoothnessScore: Double?
    var transparencyArtifactsScore: Double?
    var resolutionOK: Bool?
    var aspectRatioOK: Bool?
    var confidenceScore: Double?
}

struct AssetProcessingInfo: Codable, Hashable {
    var startedAt: Date?
    var finishedAt: Date?
    var durationSeconds: Double?
    var fileSizeBytes: Int64?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var confidenceScore: Double?
    var warnings: [String]

    init(
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        durationSeconds: Double? = nil,
        fileSizeBytes: Int64? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        confidenceScore: Double? = nil,
        warnings: [String] = []
    ) {
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.confidenceScore = confidenceScore
        self.warnings = warnings
    }
}

struct AssetItem: Identifiable, Codable, Hashable {
    var id: UUID
    var url: URL
    var fileName: String
    var status: AssetStatus
    var approvalStatus: AssetApprovalStatus
    var processingProgress: Double
    var errorMessage: String?
    var outputURL: URL?
    var maskURL: URL?
    var bookmarkKey: String?
    var metadata: AssetMetadata
    var quality: AssetQualityMetrics
    var processingInfo: AssetProcessingInfo
    var notes: String?

    init(
        id: UUID = UUID(),
        url: URL,
        fileName: String? = nil,
        status: AssetStatus = .pending,
        approvalStatus: AssetApprovalStatus = .pending,
        processingProgress: Double = 0,
        errorMessage: String? = nil,
        outputURL: URL? = nil,
        maskURL: URL? = nil,
        bookmarkKey: String? = nil,
        metadata: AssetMetadata = AssetMetadata(),
        quality: AssetQualityMetrics = AssetQualityMetrics(),
        processingInfo: AssetProcessingInfo = AssetProcessingInfo(),
        notes: String? = nil
    ) {
        self.id = id
        self.url = url
        self.fileName = fileName ?? url.deletingPathExtension().lastPathComponent
        self.status = status
        self.approvalStatus = approvalStatus
        self.processingProgress = processingProgress
        self.errorMessage = errorMessage
        self.outputURL = outputURL
        self.maskURL = maskURL
        self.bookmarkKey = bookmarkKey
        self.metadata = metadata
        self.quality = quality
        self.processingInfo = processingInfo
        self.notes = notes
    }
}
