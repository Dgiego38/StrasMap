import Foundation
import CoreLocation

// MARK: - Modèles CTS Tramway
struct TramStationResponse: Codable {
    let results: [TramStationRecord]
}

struct TramStationRecord: Codable {
    let nomArret: String?
    let ligneS: String?
    let geoPoint2d: GeoPoint2D?
    let geometry: GeoGeometry?
    
    enum CodingKeys: String, CodingKey {
        case nomArret = "nom_arret"
        case ligneS = "ligne_s"
        case geoPoint2d = "geo_point_2d"
        case geometry = "geometry"
    }
}

struct GeoPoint2D: Codable {
    let lat: Double
    let lon: Double
}

struct GeoGeometry: Codable {
    let coordinates: [Double]? // [longitude, latitude]
}

// MARK: - Helper de chargement CTS
class TransportctsModel {
    static func fetchTramStations() async throws -> [TramStationRecord] {
        // Endpoint officiel v2.1 Open Data Strasbourg pour les stations de tram
        let urlString = "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/stations_tram/records?limit=100"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(TramStationResponse.self, from: data)
        return decodedResponse.results
    }
}