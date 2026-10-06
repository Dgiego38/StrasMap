import SwiftUI
import MapKit
import CoreLocation

// MARK: - Modèles et Énumérations

enum POIType: String, Codable, CaseIterable {
    case toilet
    case velhop
    case tram
}

struct POIItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let type: POIType
    let description: String
    
    static func == (lhs: POIItem, rhs: POIItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum ThemeMode: String, CaseIterable, Identifiable {
    case system = "Système"
    case light = "Clair"
    case dark = "Sombre"
   
    var id: String { self.rawValue }
   
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum MapStyleOption {
    case standard, satellite
}

enum SortOption {
    case distance, count
}

// MARK: - Gestionnaire de localisation simple

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.currentLocation = location
    }
}

// MARK: - Modèles de données fictifs/interface pour les services

struct ToiletteModel {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String?
    
    static func fetchAndMergeToilets() async throws -> [ToiletteModel] {
        return [
            ToiletteModel(name: "Toilettes Place Kléber", coordinate: CLLocationCoordinate2D(latitude: 48.5839, longitude: 7.7455), address: "Place Kléber")
        ]
    }
}

struct VelhopModel {
    let nom: String?
    let coordinate: CLLocationCoordinate2D?
    let nbrVelosDispo: Int?
    
    static func fetchStations() async throws -> [VelhopModel] {
        return [
            VelhopModel(nom: "Station Homme de Fer", coordinate: CLLocationCoordinate2D(latitude: 48.5834, longitude: 7.7431), nbrVelosDispo: 12)
        ]
    }
}

struct TransportctsModel {
    let nomArret: String?
    let ligneS: String?
    let geoPoint2d: GeoPoint?
    let geometry: GeoGeometry?
    
    struct GeoPoint {
        let lat: Double
        let lon: Double
    }
    
    struct GeoGeometry {
        let coordinates: [Double]
    }
    
    static func fetchTramStations() async throws -> [TransportctsModel] {
        return [
            TransportctsModel(nomArret: "Homme de Fer", ligneS: "A, B, C, D", geoPoint2d: GeoPoint(lat: 48.5834, lon: 7.7431), geometry: nil)
        ]
    }
}

// MARK: - Vue Principale

struct ContentView: View {
    @StateObject private var viewModel = MapViewModel()
   
    @State private var selectedTab: String = "map"
    @State private var selectedCategoryFilter: POIType? = nil
    @State private var isSheetExpanded: Bool = false
    @State private var sortOption: SortOption = .distance
   
    @AppStorage("themeMode") private var themeMode: ThemeMode = .system
    @StateObject private var locationManager = LocationManager()
   
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
        let baseList = viewModel.pois
        let categoryFiltered: [POIItem]
        if let filter = selectedCategoryFilter {
            categoryFiltered = baseList.filter { $0.type == filter }
        } else {
            categoryFiltered = baseList
        }
       
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.description.localizedStandardContains(searchText)
            }
        }
    }
   
    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                // 1. ONGLET CARTE
                if selectedTab == "map" {
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        ForEach(filteredPois) { poi in
                            Annotation("", coordinate: poi.coordinate) {
                                Button(action: {
                                    selectedPoi = poi
                                    isSheetExpanded = false
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 36, height: 36)
                                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                     
                                        Text(poi.type == .toilet ? "🚻" : (poi.type == .velhop ? "🚲" : "🚊"))
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                        }
                    }
                    .mapStyle(mapStyleOption == .standard ? .standard : .imagery(elevation: .realistic))
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                        MapUserLocationButton()
                    }
                    .ignoresSafeArea()
                   
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Rechercher...", text: $searchText)
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
                       
                        if let filter = selectedCategoryFilter {
                            HStack {
                                Text(filter == .toilet ? "🚻 Filtre : Toilettes" : (filter == .velhop ? "🚲 Filtre : Vélhop" : "🚊 Filtre : Tramway CTS"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Button(action: {
                                    selectedCategoryFilter = nil
                                    isSheetExpanded = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 50)
                   
                    if selectedCategoryFilter != nil {
                        VStack(spacing: 0) {
                            Button(action: {
                                withAnimation(.spring()) {
                                    isSheetExpanded.toggle()
                                }
                            }) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.5))
                                    .frame(width: 40, height: 5)
                                    .padding(.top, 8)
                                    .padding(.bottom, 6)
                            }
                           
                            HStack {
                                Text(selectedCategoryFilter == .toilet ? "Toilettes publiques" : (selectedCategoryFilter == .velhop ? "Stations Vélhop" : "Stations de Tram"))
                                    .font(.headline)
                                Spacer()
                               
                                Picker("Tri", selection: $sortOption) {
                                    Text("Proche").tag(SortOption.distance)
                                    Text("Dispo").tag(SortOption.count)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 150)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                           
                            if isSheetExpanded {
                                Divider()
                                List(sortedFilteredPois) { poi in
                                    Button(action: {
                                        cameraPosition = .region(MKCoordinateRegion(center: poi.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)))
                                        selectedPoi = poi
                                        isSheetExpanded = false
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(poi.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.primary)
                                                Text(poi.description)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .listStyle(.plain)
                                .frame(height: 220)
                            }
                        }
                        .padding(.bottom, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 16)
                        .padding(.top, 120)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                   
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
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                   
                // 2. ONGLET CATEGORIES
                } else if selectedTab == "categories" {
                    CategoriesView(
                        selectedCategoryFilter: $selectedCategoryFilter,
                        selectedTab: $selectedTab,
                        isSheetExpanded: $isSheetExpanded
                    )
                    .transition(.opacity)
               
                // 3. ONGLET PARAMETRES
                } else if selectedTab == "settings" {
                    SettingsView(mapStyleOption: $mapStyleOption, themeMode: $themeMode)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
           
            // --- BARRE D'ONGLETS FLOTTANTE ---
            HStack(spacing: 24) {
                TabButton(icon: "map.fill", title: "Carte", isSelected: selectedTab == "map") {
                    selectedTab = "map"
                }
               
                TabButton(icon: "square.grid.2x2.fill", title: "Catégories", isSelected: selectedTab == "categories") {
                    selectedTab = "categories"
                }
               
                TabButton(icon: "gearshape.fill", title: "Paramètres", isSelected: selectedTab == "settings") {
                    selectedTab = "settings"
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
            .padding(.bottom, 24)
        }
        .preferredColorScheme(themeMode.colorScheme)
        .task {
            await viewModel.loadAllData()
        }
    }
   
    var sortedFilteredPois: [POIItem] {
        let items = filteredPois
       
        return items.sorted(by: { item1, item2 in
            if sortOption == .distance {
                let loc1 = CLLocation(latitude: item1.coordinate.latitude, longitude: item1.coordinate.longitude)
                let loc2 = CLLocation(latitude: item2.coordinate.latitude, longitude: item2.coordinate.longitude)
                let refLocation = locationManager.currentLocation ?? CLLocation(latitude: 48.5839, longitude: 7.7455)
                return loc1.distance(from: refLocation) < loc2.distance(from: refLocation)
            } else {
                let count1 = extractBikeCount(from: item1.description)
                let count2 = extractBikeCount(from: item2.description)
                return count1 > count2
            }
        })
    }
   
    private func extractBikeCount(from text: String) -> Int {
        let components = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
        let numbers = components.compactMap { Int($0) }
        return numbers.last ?? 0
    }
}

// MARK: - Sous-vues

struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
   
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }
}

struct CategoriesView: View {
    @Binding var selectedCategoryFilter: POIType?
    @Binding var selectedTab: String
    @Binding var isSheetExpanded: Bool
   
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CategoryCard(
                        title: "Toilettes Publiques",
                        subtitle: "Trouvez les toilettes accessibles à proximité",
                        icon: "🚻",
                        color: LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ) {
                        selectedCategoryFilter = .toilet
                        selectedTab = "map"
                        isSheetExpanded = true
                    }
                   
                    CategoryCard(
                        title: "Stations Vélhop",
                        subtitle: "Vélos partagés de l'Eurométropole",
                        icon: "🚲",
                        color: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ) {
                        selectedCategoryFilter = .velhop
                        selectedTab = "map"
                        isSheetExpanded = true
                    }

                    CategoryCard(
                        title: "Tramway CTS",
                        subtitle: "Réseau de tramways de Strasbourg",
                        icon: "🚊",
                        color: LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ) {
                        selectedCategoryFilter = .tram
                        selectedTab = "map"
                        isSheetExpanded = true
                    }
                   
                    CategoryCard(
                        title: "Prochainement...",
                        subtitle: "Nouvelles catégories à venir",
                        icon: "✨",
                        color: LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ) {}
                    .opacity(0.6)
                }
                .padding(16)
                .padding(.bottom, 100)
            }
            .navigationTitle("Catégories")
        }
    }
}

struct CategoryCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: LinearGradient
    let action: () -> Void
   
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(icon)
                    .font(.system(size: 36))
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
               
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(18)
            .background(color)
            .cornerRadius(22)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
}

struct SettingsView: View {
    @Binding var mapStyleOption: MapStyleOption
    @Binding var themeMode: ThemeMode
   
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Apparence")) {
                    Picker("Mode d'affichage", selection: $themeMode) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
               
                Section(header: Text("Apparence de la carte")) {
                    Picker("Style de carte", selection: $mapStyleOption) {
                        Text("Plan standard").tag(MapStyleOption.standard)
                        Text("Satellite 3D").tag(MapStyleOption.satellite)
                    }
                }
               
                Section(header: Text("À propos")) {
                    HStack {
                        Text("Application")
                        Spacer()
                        Text("StrasbourgMap v1.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Source des données")
                        Spacer()
                        Text("data.strasbourg.eu")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Paramètres")
            .padding(.bottom, 80)
        }
    }
}

// MARK: - ViewModel

@MainActor
class MapViewModel: ObservableObject {
    @Published var pois: [POIItem] = []
    @Published var isLoading: Bool = false

    func loadAllData() async {
        isLoading = true
        var loadedPois: [POIItem] = []
       
        do {
            let toilets = try await ToiletteModel.fetchAndMergeToilets()
            for t in toilets {
                let adresseText = t.address ?? "Adresse non spécifiée"
                let description = "📍 \(adresseText)"
               
                loadedPois.append(POIItem(
                    name: t.name,
                    coordinate: t.coordinate,
                    type: .toilet,
                    description: description
                ))
            }
        } catch {
            print("Erreur chargement toilettes : \(error)")
        }
       
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

        do {
            let tramStations = try await TransportctsModel.fetchTramStations()
            for record in tramStations {
                let name = record.nomArret ?? "Station de Tram"
                let lines = record.ligneS ?? "Lignes multiples"
                
                var coordinate: CLLocationCoordinate2D?
                if let pt = record.geoPoint2d {
                    coordinate = CLLocationCoordinate2D(latitude: pt.lat, longitude: pt.lon)
                } else if let coords = record.geometry?.coordinates, coords.count >= 2 {
                    coordinate = CLLocationCoordinate2D(latitude: coords[1], longitude: coords[0])
                }
                
                if let coord = coordinate {
                    loadedPois.append(POIItem(
                        name: name,
                        coordinate: coord,
                        type: .tram,
                        description: "🚊 Tram - Lignes : \(lines)"
                    ))
                }
            }
        } catch {
            print("Erreur chargement Trams CTS : \(error)")
        }
       
        self.pois = loadedPois
        self.isLoading = false
    }
}