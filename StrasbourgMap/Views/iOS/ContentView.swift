import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager()
    @StateObject private var locationManager = LocationManager() // <-- Ajout du gestionnaire GPS
    
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.5734, longitude: 7.7521), // Centre de Strasbourg
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var searchText = ""
    @State private var selectedVelhop: VelhopRecord?

    var body: some View {
        ZStack(alignment: .top) {
            // 1. Carte Apple Plan avec affichage de la position utilisateur
            Map(position: $position) {
                UserAnnotation() // Affiche le point bleu de l'utilisateur

                ForEach(networkManager.velhops) { velhop in
                    if let coords = velhop.geoPoint2d, coords.count == 2 {
                        Annotation(velhop.nom ?? "Vélhop", coordinate: CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])) {
                            Button(action: {
                                selectedVelhop = velhop
                            }) {
                                Image(systemName: "bicycle")
                                    .padding(8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                networkManager.fetchVelhops()
            }

            // 2. Barre de recherche (Glassmorphism)
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Rechercher Vélhop...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                .padding(.top, 50)
                
                Spacer()

                // 3. Fiche d'information dynamique
                if let velhop = selectedVelhop {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(velhop.nom ?? "Station Vélhop")
                            .font(.headline)
                        Text("🚲 \(velhop.nbrVelosDispo ?? 0) vélos disponibles")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Button("Y aller") {
                                if let coords = velhop.geoPoint2d, coords.count == 2 {
                                    let coordinate = CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
                                    let placemark = MKPlacemark(coordinate: coordinate)
                                    let mapItem = MKMapItem(placemark: placemark)
                                    mapItem.name = velhop.nom
                                    mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Fermer") {
                                selectedVelhop = nil
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding()
                }
            }
        }
    }
}