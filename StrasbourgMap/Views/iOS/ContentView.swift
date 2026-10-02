import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager()
    @StateObject private var locationManager = LocationManager()
    
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.5734, longitude: 7.7521),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var searchText = ""
    @State private var selectedItem: MapItemModel?
    
    // Simulation d'une liste de toilettes (à connecter à ton API toilettes si tu l'as déjà dans NetworkManager)
    @State private var toilets: [MapItemModel] = [
        MapItemModel(id: "t1", name: "Toilettes Place Kléber", coordinate: CLLocationCoordinate2D(latitude: 48.5834, longitude: 7.7475), type: .toilette, availableBikes: nil, details: "Ouvert 24/7 - Accès PMR")
    ]

    // Fusion et Filtrage intelligent
    var filteredItems: [MapItemModel] {
        var items: [MapItemModel] = []
        
        // Convertir les Vélhop
        let velhops = networkManager.velhops.compactMap { v -> MapItemModel? in
            guard let lat = v.lat, let lon = v.lon else { return nil }
            return MapItemModel(
                id: v.id ?? UUID().uuidString,
                name: v.nom ?? "Station Vélhop",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                type: .velhop,
                availableBikes: v.nbrVelosDispo ?? 0,
                details: "Station automatique Vélhop\nNombre de bornettes actives: \(v.nbrBornettesDispo ?? 0)"
            )
        }
        
        items.append(contentsOf: velhops)
        items.append(contentsOf: toilets)
        
        // Si recherche "velhop", on filtre et on trie par ordre croissant de vélos dispo
        let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if query == "velhop" {
            let onlyVelhops = items.filter { $0.type == .velhop }
            return onlyVelhops.sorted { ($0.availableBikes ?? 0) < ($1.availableBikes ?? 0) }
        } else if !query.isEmpty {
            return items.filter { $0.name.lowercased().contains(query) }
        }
        
        return items
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 1. Carte épurée
            Map(position: $position) {
                UserAnnotation()

                ForEach(filteredItems) { item in
                    Annotation(item.name, coordinate: item.coordinate) {
                        Button(action: {
                            selectedItem = item
                        }) {
                            Circle()
                                .fill(item.type == .velhop ? ((item.availableBikes ?? 0) > 0 ? Color.blue : Color.red) : Color.orange)
                                .frame(width: 12, height: 12)
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excluding([.restaurant, .cafe, .hotel, .store, .bakery, .bank, .park, .hospital, .school])))
            .ignoresSafeArea()
            .onChange(of: locationManager.authorizationStatus) { _, status in
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    if let location = locationManager.currentLocation {
                        position = .region(
                            MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    }
                }
            }

            // 2. Barre de recherche avec indication textuelle
            VStack {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Rechercher ou tape 'velhop'...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    if searchText.lowercased() == "velhop" {
                        Text("💡 Trié par nombre de vélos croissant")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                .padding(.top, 60)
                
                Spacer()

                // 3. Fiche détaillée enrichie
                if let item = selectedItem {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if item.type == .velhop {
                                    Text("🚲 \(item.availableBikes ?? 0) vélos disponibles")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(item.availableBikes ?? 0 > 0 ? .blue : .red)
                                } else {
                                    Text("🚻 Toilettes publiques")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }
                            }
                            Spacer()
                            Button(action: { selectedItem = nil }) {
                                Image(systemName: "xmark")
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                        
                        // Infos supplémentaires
                        if let details = item.details {
                            Text(details)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            let placemark = MKPlacemark(coordinate: item.coordinate)
                            let mapItem = MKMapItem(placemark: placemark)
                            mapItem.name = item.name
                            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                        }) {
                            Text("Y aller (Itinéraire)")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 10)
                    .padding()
                }
            }
        }
        .onAppear {
            networkManager.fetchVelhops()
        }
    }
}