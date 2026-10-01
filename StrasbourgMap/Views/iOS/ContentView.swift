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
    @State private var selectedVelhop: VelhopRecord?

    var filteredVelhops: [VelhopRecord] {
        if searchText.isEmpty {
            return networkManager.velhops
        } else {
            return networkManager.velhops.filter { velhop in
                (velhop.nom ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 1. Carte épurée : on cache tous les commerces/restaurants d'Apple Plans
            Map(position: $position) {
                UserAnnotation()

                ForEach(filteredVelhops) { velhop in
                    if let lat = velhop.lat, let lon = velhop.lon {
                        Annotation(velhop.nom ?? "Vélhop", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            Button(action: {
                                selectedVelhop = velhop
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bicycle")
                                    if let velos = velhop.nbrVelosDispo {
                                        Text("\(velos)")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                }
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                                .shadow(radius: 4)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excluding([.restaurant, .cafe, .hotel, .store, .bakery, .bank])))
            .ignoresSafeArea()
            .onChange(of: locationManager.authorizationStatus) { status in
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

            // 2. Barre de recherche (Glassmorphism)
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Rechercher une station Vélhop...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                .padding(.top, 60)
                
                Spacer()

                // 3. Fiche d'information de la station sélectionnée
                if let velhop = selectedVelhop {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(velhop.nom ?? "Station Vélhop")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("🚲 \(velhop.nbrVelosDispo ?? 0) vélos disponibles")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { selectedVelhop = nil }) {
                                Image(systemName: "xmark")
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }

                        Button(action: {
                            if let lat = velhop.lat, let lon = velhop.lon {
                                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                                let placemark = MKPlacemark(coordinate: coordinate)
                                let mapItem = MKMapItem(placemark: placemark)
                                mapItem.name = velhop.nom
                                mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                            }
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