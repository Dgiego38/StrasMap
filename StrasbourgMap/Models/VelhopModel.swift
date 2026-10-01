import Foundation

struct VelhopRecord: Codable, Identifiable {
    let id = UUID()
    let nom: String?
    let nbrVelosDispo: Int?
    let geoPoint2d: [Double]? // [lat, lon]

    enum CodingKeys: String, CodingKey {
        case nom = "nom_station"
        case nbrVelosDispo = "nombre_velos_disponibles"
        case geoPoint2d = "geo_point_2d"
    }
}

struct OpenDataResponse: Codable {
    let results: [VelhopRecord]
}