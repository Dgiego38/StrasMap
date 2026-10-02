import Foundation
import Combine

class NetworkManager: ObservableObject {
    @Published var velhops: [VelhopRecord] = []

    func fetchVelhops() {
        guard let url = URL(string: "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/stations-velhop/records?limit=30") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            do {
                let decodedResponse = try JSONDecoder().decode(OpenDataResponse.self, from: data)
                DispatchQueue.main.async {
                    self.velhops = decodedResponse.results
                }
            } catch {
                print("Erreur de décodage JSON : \(error)")
            }
        }.resume()
    }
}