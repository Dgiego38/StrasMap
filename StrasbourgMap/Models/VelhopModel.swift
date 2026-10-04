import Foundation
import CoreLocation

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

    // Propriété pratique pour récupérer directement la coordonnée MapKit
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lon = lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
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

struct VelhopModel {
    // Fonction statique appelée par le ViewModel pour récupérer les stations Vélhop en ligne
    static func fetchStations() async throws -> [VelhopRecord] {
        let urlString = "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/stations-velhop/records?limit=100"
        
        guard let url = URL(string: urlString) else {
            return []
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(OpenDataResponse.self, from: data)
        
        // On retourne uniquement les stations qui possèdent des coordonnées GPS valides
        return decoded.results.filter { $0.coordinate != nil }
    }
}