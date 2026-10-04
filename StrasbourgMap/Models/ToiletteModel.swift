import Foundation
import CoreLocation

struct ToiletteModel: Identifiable, Codable {
    let id: String
    let nom: String
    let adresse: String?
    let coordinate: CLLocationCoordinate2D
    let source: String

    // Struct pour décoder l'API OpenData Strasbourg v2.1 (format standard records)
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
    
    // Fonction statique pour récupérer et croiser les deux datasets
    static func fetchAndMergeToilets() async throws -> [ToiletteModel] {
        let urlLieuxStr = "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/lieux_toilettes_publiques/records?limit=100"
        let urlPropreteStr = "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/toilette_publique/records?limit=100"
        
        guard let urlLieux = URL(string: urlLieuxStr),
              let urlProprete = URL(string: urlPropreteStr) else {
            return []
        }
        
        // Requêtes parallèles
        async let (dataLieux, _) = URLSession.shared.data(from: urlLieux)
        async let (dataProprete, _) = URLSession.shared.data(from: urlProprete)
        
        var combinedToilets: [ToiletteModel] = []
        let decoder = JSONDecoder()
        
        // 1. Parsing du premier dataset (lieux_toilettes_publiques)
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
        
        // 2. Parsing du second dataset (toilette_publique)
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
        
        // 3. Dédoublonnage géographique (si un point est à moins de 15 mètres d'un autre)
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