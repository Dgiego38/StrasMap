import SwiftUI
import MapKit

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
            // Carte principale avec MapKit (style Apple Maps)
            Map(position: $cameraPosition) {
                ForEach(filteredPois) { poi in
                    Annotation(poi.name, coordinate: poi.coordinate) {
                        Button(action: {
                            selectedPoi = poi
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                
                                Text(poi.type == .toilet ? "🚻" : "🚲")
                                    .font(.system(size: 16))
                            }
                        }
                    }
                }
            }
            // Utilisation d'un style satellite réaliste d'Apple Maps avec relief 3D
            .mapStyle(mapStyleOption == .standard ? .standard : .imagery(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
                MapUserLocationButton()
            }
            .ignoresSafeArea()
            
            // Interface utilisateur superposée
            VStack(spacing: 12) {
                // Barre de recherche et de choix de style
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Rechercher un Vélhop, toilette...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Sélecteur de mode de carte (Plan / Satellite réaliste)
                    Picker("Style de carte", selection: $mapStyleOption) {
                        Text("Plan").tag(MapStyleOption.standard)
                        Text("Satellite").tag(MapStyleOption.satellite)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // Liste horizontale des résultats filtrés si recherche active
                if !searchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filteredPois) { poi in
                                Button(action: {
                                    cameraPosition = .region(MKCoordinateRegion(center: poi.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)))
                                    selectedPoi = poi
                                }) {
                                    HStack(spacing: 6) {
                                        Text(poi.type == .toilet ? "🚻" : "🚲")
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
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(poi.name)
                                .font(.headline)
                            Spacer()
                            Button(action: { selectedPoi = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            }
                        }
                        Text(poi.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedPoi)
                }
            }
        }
        .task {
            await viewModel.loadAllData()
        }
    }
}

enum MapStyleOption {
    case standard, satellite
}

// MARK: - ViewModel
@MainActor
class MapViewModel: ObservableObject {
    @Published var pois: [POIItem] = []
    @Published var isLoading: Bool = false

    func loadAllData() async {
        isLoading = true
        var loadedPois: [POIItem] = []
        
        // 1. Chargement des Toilettes via ToiletteModel
        do {
            let toilets = try await ToiletteModel.fetchAndMergeToilets()
            for t in toilets {
                let adresseText = t.adresse ?? "Adresse non spécifiée"
                let description = "📍 \(adresseText)\nSource : \(t.source == "lieux" ? "Lieux publics" : "Propreté urbaine")"
                
                loadedPois.append(POIItem(
                    name: t.nom,
                    coordinate: t.coordinate,
                    type: .toilet,
                    description: description
                ))
            }
        } catch {
            print("Erreur chargement toilettes : \(error)")
        }
        
        // 2. Chargement des Vélhops via VelhopModel
        do {
            let stations = try await VelhopModel.fetchStations()
            for s in stations {
                if let coord = s.coordinate {
                    loadedPois.append(POIItem(
                        name: s.nom ?? "Station Vélhop",
                        coordinate: coord,
                        type: .velhop,
                        description: "🚲 Station Vélhop\nVélos disponibles : \(s.nbrVelosDispo ?? 0)"
                    ))
                }
            }
        } catch {
            print("Erreur chargement Vélhop : \(error)")
        }
        
        self.pois = loadedPois
        self.isLoading = false
    }
}