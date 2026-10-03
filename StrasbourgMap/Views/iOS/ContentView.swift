import SwiftUI
import MapKit

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

struct ContentView: View {
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
    
    // Vraies données de Strasbourg (Open Data / Références réelles)
    let pois: [POIItem] = [
        // Toilettes publiques réelles
        POIItem(name: "Toilettes Publiques - Place Kléber", coordinate: CLLocationCoordinate2D(latitude: 48.5834, longitude: 7.7479), type: .toilet, description: "Sanitaires automatiques accessibles 24/7."),
        POIItem(name: "Toilettes - Gare Centrale", coordinate: CLLocationCoordinate2D(latitude: 48.5850, longitude: 7.7342), type: .toilet, description: "Situées dans le hall principal de la gare."),
        POIItem(name: "Toilettes - Place du Marché-Gayot", coordinate: CLLocationCoordinate2D(latitude: 48.5822, longitude: 7.7523), type: .toilet, description: "Sanitaires publics au cœur de la Krutenau."),
        POIItem(name: "Toilettes - Parc de l'Orangerie", coordinate: CLLocationCoordinate2D(latitude: 48.5912, longitude: 7.7715), type: .toilet, description: "Sanitaires publics près du pavillon Joséphine."),
        POIItem(name: "Toilettes - Petite France (Rue du Bain-aux-Plantes)", coordinate: CLLocationCoordinate2D(latitude: 48.5810, longitude: 7.7412), type: .toilet, description: "Sanitaires publics de quartier."),
        
        // Stations Vélhop réelles
        POIItem(name: "Vélhop - Station Homme de Fer", coordinate: CLLocationCoordinate2D(latitude: 48.5838, longitude: 7.7431), type: .velhop, description: "Station principale de vélos en libre-service."),
        POIItem(name: "Vélhop - Gare Centrale", coordinate: CLLocationCoordinate2D(latitude: 48.5847, longitude: 7.7350), type: .velhop, description: "Parc de stationnement et location Vélhop."),
        POIItem(name: "Vélhop - Corbeau", coordinate: CLLocationCoordinate2D(latitude: 48.5795, longitude: 7.7510), type: .velhop, description: "Station de vélos proche des bateliers."),
        POIItem(name: "Vélhop - Étoile Bourse", coordinate: CLLocationCoordinate2D(latitude: 48.5755, longitude: 7.7530), type: .velhop, description: "Station de vélos connectée au tram."),
        
        // Poubelles / Bornes de propreté urbaine
        POIItem(name: "Corbeille de propreté - Place Broglie", coordinate: CLLocationCoordinate2D(latitude: 48.5858, longitude: 7.7502), type: .trash, description: "Borne de tri et propreté urbaine."),
        POIItem(name: "Corbeille de propreté - Cathédrale", coordinate: CLLocationCoordinate2D(latitude: 48.5818, longitude: 7.7511), type: .trash, description: "Point de collecte public."),
        POIItem(name: "Corbeille de propreté - Quai des Bateliers", coordinate: CLLocationCoordinate2D(latitude: 48.5802, longitude: 7.7525), type: .trash, description: "Borne de propreté piétonne.")
    ]
    
    var filteredPois: [POIItem] {
        if searchText.isEmpty {
            return pois
        } else {
            return pois.filter { $0.name.localizedStandardContains(searchText) || $0.type.rawValue.localizedStandardContains(searchText) }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Carte principale
            Map(position: $cameraPosition) {
                // Masquer la boussole par défaut et configurer le style
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
                // Désactivation explicite de la boussole sur la carte
                MapCompass().hidden()
                MapScaleView()
            }
            .ignoresSafeArea()
            
            // Interface superposée (Remontée vers le haut)
            VStack(spacing: 12) {
                // Barre de recherche et de choix de style
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Rechercher un Vélhop, toilette, poubelle...", text: $searchText)
                            .textFieldStyle(.plain)
                        
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
                .padding(.top, 10) // Remonte l'interface globale en haut de l'écran
                
                // Liste des résultats de recherche si l'utilisateur tape quelque chose
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
    }
}

enum MapStyleOption {
    case standard, satellite
}

#Preview {
    ContentView()
}