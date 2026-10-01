import Foundation

struct VelhopRecord: Codable, Identifiable {
    var id: String { stationId }
    let stationId: String
    let nom: String?
    let nbrVelosDispo: Int?
    let lat: Double?
    let lon: Double?

    enum CodingKeys: String, CodingKey {
        case stationId = "id"
        case nom = "na"
        case nbrVelosDispo = "av"
        case lat
        case lon
    }
}

struct OpenDataResponse: Codable {
    let totalCount: Int?
    let results: [VelhopRecord]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case results
    }
}