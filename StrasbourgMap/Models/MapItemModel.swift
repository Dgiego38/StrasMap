import Foundation
import SwiftUI
import CoreLocation

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