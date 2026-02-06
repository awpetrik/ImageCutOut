import Foundation

struct SKUMapEntry: Codable, Hashable, Identifiable {
    var id: UUID
    var sku: String
    var filenamePattern: String
    var brand: String?
    var category: String?
    var variant: String?

    init(id: UUID = UUID(), sku: String, filenamePattern: String, brand: String? = nil, category: String? = nil, variant: String? = nil) {
        self.id = id
        self.sku = sku
        self.filenamePattern = filenamePattern
        self.brand = brand
        self.category = category
        self.variant = variant
    }
}

struct CSVExportRow: Codable, Hashable {
    var filename: String
    var sku: String
    var name: String
    var brand: String
    var category: String
    var tags: String
    var generatedAt: String
}
