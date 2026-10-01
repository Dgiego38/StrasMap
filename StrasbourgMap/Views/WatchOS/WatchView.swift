import SwiftUI
import MapKit

struct WatchMapView: View {
    @StateObject private var networkManager = NetworkManager()
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.5734, longitude: 7.7521),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005) // Zoom rapproché pour la montre
        )
    )
    @State private var selectedVelhop: VelhopRecord?

    var body: some View {
        ZStack(alignment: .top) {
            // Carte Apple Plan adaptée watchOS
            Map(position: $position) {
                UserAnnotation()

                ForEach(networkManager.velhops) { velhop in
                    if let lat = velhop.lat, let lon = velhop.lon {
                        Annotation(velhop.nom ?? "", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            Button(action: {
                                selectedVelhop = velhop
                            }) {
                                Image(systemName: "bicycle")
                                    .padding(6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                networkManager.fetchVelhops()
            }

            // Fiche d'information compacte pour l'écran de la montre
            if let velhop = selectedVelhop {
                VStack(spacing: 4) {
                    Text(velhop.nom ?? "Station")
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    Text("🚲 \(velhop.nbrVelosDispo ?? 0) dispo")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Button("Fermer") {
                        selectedVelhop = nil
                    }
                    .font(.system(size: 9))
                    .buttonStyle(.bordered)
                }
                .padding(6)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .padding(.top, 10)
            }
        }
    }
} 