import Foundation
import CoreLocation

struct ToiletteItem: Identifiable, Codable {
    let id = UUID()
    let name: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
    
    enum CodingKeys: String, CodingKey {
        case name
        case address
        case pointGeo = "point_geo"
    }
    
    struct PointGeo: Codable {
        let lon: Double
        let lat: Double
    }
    
    let pointGeo: PointGeo
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        pointGeo = try container.decode(PointGeo.self, forKey: .pointGeo)
        coordinate = CLLocationCoordinate2D(latitude: pointGeo.lat, longitude: pointGeo.lon)
    }
    
    init(name: String, address: String?, coordinate: CLLocationCoordinate2D, pointGeo: PointGeo) {
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.pointGeo = pointGeo
    }
}

struct ToiletteResponse: Codable {
    let totalCount: Int
    let results: [ToiletteItem]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case results
    }
}

class ToiletteModel {
    static func fetchAndMergeToilets() async throws -> [ToiletteItem] {
        let urlString = "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/lieux_toilettes_publiques/records?limit=50"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decodedResponse = try JSONDecoder().decode(ToiletteResponse.self, from: data)
        
        return decodedResponse.results
    }
}