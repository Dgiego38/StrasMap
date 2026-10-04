import SwiftUI
import MapKit

// MARK: - Modèles de Données & ViewModel

struct POIItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let type: POIType
    let description: String
    
    static func == (lhs: POIItem, rhs: POIItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum POIType: String, CaseIterable {
    case velhop = "Vélhop"
    case toilet = "Toilettes"
    case trash = "Poubelles"
    
    var icon: String {
        switch self {
        case .velhop: return "bicycle"
        case .toilet: return "figure.restroom"
        case .trash: return "trash"
        }
    }
    
    var color: Color {
        switch self {
        case .velhop: return .orange
        case .toilet: return .blue
        case .trash: return .green
        }
    }
}

@MainActor
class MapViewModel: ObservableObject {
    @Published var pois: [POIItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Structures pour décoder l'Open Data de Strasbourg (API v2.1)
    private struct OpenDataResponse: Codable {
        let results: [Record]
    }
    
    private struct Record: Codable {
        let recordid: String?
        let nom: String?
        let adresse: String?
        let libelle: String?
        let type: String?
        let geo_point_2d: GeoPoint?
    }
    
    private struct GeoPoint: Codable {
        let lat: Double
        let lon: Double
    }

    func loadAllData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let velhopData = fetchDataset(urlString: "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/stations-velhop/records?limit=100", type: .velhop)
            async let toiletsLieux = fetchDataset(urlString: "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/lieux_toilettes_publiques/records?limit=100", type: .toilet)
            async let toiletsProprete = fetchDataset(urlString: "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/toilette_publique/records?limit=100", type: .toilet)
            async let trashData = fetchDataset(urlString: "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/corbeilles_de_proprete/records?limit=100", type: .trash)
            
            let results = try await [velhopData, toiletsLieux, toiletsProprete, trashData]
            let allItems = results.flatMap { $0 }
            
            // Dédoublonnage pour éviter les doublons entre les deux datasets de toilettes
            self.pois = deduplicate(toilets: allItems)
            self.isLoading = false
        } catch {
            self.errorMessage = "Impossible de charger les données Open Data."
            self.isLoading = false
        }
    }
    
    private func fetchDataset(urlString: String, type: POIType) async throws -> [POIItem] {
        guard let url = URL(string: urlString) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(OpenDataResponse.self, from: data)
        
        var items: [POIItem] = []
        for record in decoded.results {
            if let point = record.geo_point_2d {
                let name = record.nom ?? record.libelle ?? (type == .velhop ? "Station Vélhop" : type == .toilet ? "Toilette publique" : "Corbeille de propreté")
                let address = record.adresse ?? "Strasbourg"
                
                let item = POIItem(
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon),
                    type: type,
                    description: address
                )
                items.append(item)
            }
        }
        return items
    }
    
    private func deduplicate(toilets: [POIItem]) -> [POIItem] {
        var unique: [POIItem] = []
        for item in toilets {
            // Si c'est une toilette, on vérifie qu'il n'y en a pas une autre à < 10m
            if item.type == .toilet {
                let isDuplicate = unique.contains { existing in
                    if existing.type != .toilet { return false }
                    let loc1 = CLLocation(latitude: existing.coordinate.latitude, longitude: existing.coordinate.longitude)
                    let loc2 = CLLocation(latitude: item.coordinate.latitude, longitude: item.coordinate.longitude)
                    return loc1.distance(from: loc2) < 10.0
                }
                if !isDuplicate { unique.append(item) }
            } else {
                unique.append(item)
            }
        }
        return unique
    }
}

// MARK: - Vue Principale

struct ContentView: View {
    @StateObject private var viewModel = MapViewModel()
    
    // Position initiale centrée sur Strasbourg (Place Kléber)
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.5839, longitude: 7.7455),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    
    @State private var mapStyleOption: MapStyleOption = .standard
    @State private var searchText: String = ""
    @State private var selectedPoi: POIItem? = nil
    
    var filteredPois: [POIItem] {
        if searchText.isEmpty {
            return viewModel.pois
        } else {
            return viewModel.pois.filter { 
                $0.name.localizedStandardContains(searchText) || 
                $0.type.rawValue.localizedStandardContains(searchText) ||
                $0.description.localizedStandardContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Carte principale
            Map(position: $cameraPosition) {
                ForEach(filteredPois) { poi in
                    Annotation(poi.name, coordinate: poi.coordinate) {
                        Button(action: {
                            selectedPoi = poi
                        }) {
                            Image(systemName: poi.type.icon)
                                .font(.system(size: 14, weight: .bold))
                                .padding(8)
                                .background(poi.type.color)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                }
            }
            .mapStyle(mapStyleOption == .standard ? .standard : .imagery)
            .mapControls {
                MapCompass().hidden()
                MapScaleView()
            }
            .ignoresSafeArea()
            
            // Interface superposée
            VStack(spacing: 12) {
                // Barre de recherche et de choix de style
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Rechercher un Vélhop, toilette, poubelle...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                    
                    // Sélecteur de mode de carte (Rues / Satellite)
                    Picker("Style de carte", selection: $mapStyleOption) {
                        Text("Plan (Rues)").tag(MapStyleOption.standard)
                        Text("Satellite").tag(MapStyleOption.satellite)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // Liste horizontale des résultats si recherche active
                if !searchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filteredPois) { poi in
                                Button(action: {
                                    cameraPosition = .region(MKCoordinateRegion(center: poi.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)))
                                    selectedPoi = poi
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: poi.type.icon)
                                            .foregroundColor(poi.type.color)
                                        Text(poi.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                Spacer()
                
                // Fiche d'information contextuelle si un POI est sélectionné
                if let poi = selectedPoi {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(poi.name, systemImage: poi.type.icon)
                                .font(.headline)
                                .foregroundColor(poi.type.color)
                            Spacer()
                            Button(action: { selectedPoi = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.title3)
                            }
                        }
                        Text(poi.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: selectedPoi)
                }
            }
        }
        .task {
            // Charger les vraies données dès l'affichage de la vue
            await viewModel.loadAllData()
        }
    }
}

enum MapStyleOption {
    case standard, satellite
}

#Preview {
    ContentView()
}