import Foundation
import CoreLocation

struct MapItemModel: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let type: ItemType
    let availableBikes: Int?
    let details: String?
    
    enum ItemType {
        case velhop, toilette
    }
}