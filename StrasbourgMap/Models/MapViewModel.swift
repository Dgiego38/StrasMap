import Foundation
import CoreLocation
import Combine

// MARK: - Modèles de données globaux partagés

enum POIType: String, Codable, Hashable {
    case toilet
    case velhop
    case tram
}

struct POIItem: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let type: POIType
    
    // Conformance Hashable manuelle pour CLLocationCoordinate2D
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
    
    static func == (lhs: POIItem, rhs: POIItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - MapViewModel

@MainActor
class MapViewModel: ObservableObject {
    @Published var pois: [POIItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Charger l'ensemble des données des APIs ouvertes de Strasbourg
    func loadAllData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let toilets = fetchToilets()
            async let velhops = fetchVelhops()
            async let trams = fetchTrams()
            
            let allPois = try await [toilets, velhops, trams].flatMap { $0 }
            self.pois = allPois
        } catch {
            self.errorMessage = "Erreur lors du chargement des données : \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Toilettes Publiques (API Strasbourg)
    private func fetchToilets() async throws -> [POIItem] {
        let urlString = "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/toilettes_publiques/records?limit=100"
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(StrasbourgResponse<ToiletteRecord>.self, from: data)
        
        return decoded.results.compactMap { record in
            guard let lat = record.geometry?.coordinates.indices.contains(1) ? record.geometry?.coordinates[1] : nil,
                  let lon = record.geometry?.coordinates.indices.contains(0) ? record.geometry?.coordinates[0] : nil else {
                return nil
            }
            
            let name = record.nom ?? record.adresse ?? "Toilettes publiques"
            let desc = [record.adresse, record.horaires].compactMap { $0 }.joined(separator: " - ")
            
            return POIItem(
                id: "toilet-\(record.objectid ?? UUID().uuidString)",
                name: name,
                description: desc.isEmpty ? "Accès libre" : desc,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                type: .toilet
            )
        }
    }
    
    // MARK: - Stations Vélhop (API Strasbourg)
    private func fetchVelhops() async throws -> [POIItem] {
        let urlString = "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/stations-velhop/records?limit=100"
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(StrasbourgResponse<VelhopRecord>.self, from: data)
        
        return decoded.results.compactMap { record in
            guard let lat = record.geometry?.coordinates.indices.contains(1) ? record.geometry?.coordinates[1] : nil,
                  let lon = record.geometry?.coordinates.indices.contains(0) ? record.geometry?.coordinates[0] : nil else {
                return nil
            }
            
            let name = record.name ?? "Station Vélhop"
            let total = record.totalstands ?? 0
            let free = record.availablebikes ?? 0
            let desc = "Vélos disponibles : \(free) / \(total)"
            
            return POIItem(
                id: "velhop-\(record.idstation ?? UUID().uuidString)",
                name: name,
                description: desc,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                type: .velhop
            )
        }
    }
    
    // MARK: - Tramway CTS (API Strasbourg)
    private func fetchTrams() async throws -> [POIItem] {
        let urlString = "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/cts-arrets-lignes/records?limit=200"
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(StrasbourgResponse<TramRecord>.self, from: data)
        
        return decoded.results.compactMap { record in
            guard let lat = record.geometry?.coordinates.indices.contains(1) ? record.geometry?.coordinates[1] : nil,
                  let lon = record.geometry?.coordinates.indices.contains(0) ? record.geometry?.coordinates[0] : nil else {
                return nil
            }
            
            let name = record.nom_arr ?? "Arrêt de tram"
            let desc = record.commune ? "Commune : \(record.commune!)" : "Réseau CTS"
            
            return POIItem(
                id: "tram-\(record.id ?? UUID().uuidString)",
                name: name,
                description: desc,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                type: .tram
            )
        }
    }
}

// MARK: - Structures de décodage JSON pour OpenData Strasbourg

struct StrasbourgResponse<T: Decodable>: Decodable {
    let results: [T]
}

struct GeoJSONGeometry: Decodable {
    let coordinates: [Double]
}

struct ToiletteRecord: Decodable {
    let objectid: Int?
    let nom: String?
    let adresse: String?
    let horaires: String?
    let geometry: GeoJSONGeometry?
}

struct VelhopRecord: Decodable {
    let idstation: String?
    let name: String?
    let totalstands: Int?
    let availablebikes: Int?
    let geometry: GeoJSONGeometry?
}

struct TramRecord: Decodable {
    let id: String?
    let nom_arr: String?
    let commune: String?
    let geometry: GeoJSONGeometry?
}