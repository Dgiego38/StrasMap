import Foundation
import CoreLocation

struct ToiletteModel: Identifiable, Codable {
    let id: String
    let nom: String
    let adresse: String?
    let coordinate: CLLocationCoordinate2D
    let source: String

    // Structs pour décoder l'API OpenData Strasbourg v2.1
    struct OpenDataResponse: Codable {
        let results: [Record]
    }
    
    struct Record: Codable {
        let recordid: String?
        let nom: String?
        let adresse: String?
        let geo_point_2d: GeoPoint?
    }
    
    struct GeoPoint: Codable {
        let lat: Double
        let lon: Double
    }
    
    // Implémentation manuelle de Codable pour gérer CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, nom, adresse, coordinate, source
    }
    
    init(id: String, nom: String, adresse: String?, coordinate: CLLocationCoordinate2D, source: String) {
        self.id = id
        self.nom = nom
        self.adresse = adresse
        self.coordinate = coordinate
        self.source = source
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        nom = try container.decode(String.self, forKey: .nom)
        adresse = try container.decodeIfPresent(String.self, forKey: .adresse)
        source = try container.decode(String.self, forKey: .source)
        
        let lat = try container.decode(Double.self, forKey: .coordinate) // Juste une astuce de décodage si besoin, ou géré via GeoPoint
        let lon = try container.decode(Double.self, forKey: .coordinate)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(nom, forKey: .nom)
        try container.encodeIfPresent(adresse, forKey: .adresse)
        try container.encode(source, forKey: .source)
        // Encode la latitude et longitude si nécessaire
    }
    
    // Fonction statique pour récupérer et croiser les deux datasets
    static func fetchAndMergeToilets() async throws -> [ToiletteModel] {
        let urlLieuxStr = "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/lieux_toilettes_publiques/records?limit=100"
        let urlPropreteStr = "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/toilette_publique/records?limit=100"
        
        guard let urlLieux = URL(string: urlLieuxStr),
              let urlProprete = URL(string: urlPropreteStr) else {
            return []
        }
        
        async let (dataLieux, _) = URLSession.shared.data(from: urlLieux)
        async let (dataProprete, _) = URLSession.shared.data(from: urlProprete)
        
        var combinedToilets: [ToiletteModel] = []
        let decoder = JSONDecoder()
        
        if let decodedLieux = try? decoder.decode(OpenDataResponse.self, from: try await dataLieux) {
            for record in decodedLieux.results {
                if let point = record.geo_point_2d {
                    let toilet = ToiletteModel(
                        id: record.recordid ?? UUID().uuidString,
                        nom: record.nom ?? "Toilette publique",
                        adresse: record.adresse,
                        coordinate: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon),
                        source: "lieux"
                    )
                    combinedToilets.append(toilet)
                }
            }
        }
        
        if let decodedProprete = try? decoder.decode(OpenDataResponse.self, from: try await dataProprete) {
            for record in decodedProprete.results {
                if let point = record.geo_point_2d {
                    let toilet = ToiletteModel(
                        id: record.recordid ?? UUID().uuidString,
                        nom: record.nom ?? "Sanisette / Toilette",
                        adresse: record.adresse,
                        coordinate: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon),
                        source: "proprete"
                    )
                    combinedToilets.append(toilet)
                }
            }
        }
        
        return deduplicate(toilets: combinedToilets)
    }
    
    private static func deduplicate(toilets: [ToiletteModel]) -> [ToiletteModel] {
        var uniqueToilets: [ToiletteModel] = []
        
        for toilet in toilets {
            let isDuplicate = uniqueToilets.contains { existing in
                let loc1 = CLLocation(latitude: existing.coordinate.latitude, longitude: existing.coordinate.longitude)
                let loc2 = CLLocation(latitude: toilet.coordinate.latitude, longitude: toilet.coordinate.longitude)
                return loc1.distance(from: loc2) < 15.0
            }
            
            if !isDuplicate {
                uniqueToilets.append(toilet)
            }
        }
        
        return uniqueToilets
    }
}