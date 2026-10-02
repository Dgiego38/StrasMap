import Foundation

struct ToiletteRecord: Codable, Identifiable {
    var id: String { idRecord ?? UUID().uuidString }
    let idRecord: String?
    let nom: String?
    let adresse: String?
    let horaires: String?
    let lat: Double?
    let lon: Double?
    
    enum CodingKeys: String, CodingKey {
        case idRecord = "recordid"
        case nom = "nom"
        case adresse = "adresse"
        case horaires = "horaires"
        case lat
        case lon
    }
}

struct ToiletteResponse: Codable {
    let totalCount: Int?
    let results: [ToiletteRecord]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case results
    }
}