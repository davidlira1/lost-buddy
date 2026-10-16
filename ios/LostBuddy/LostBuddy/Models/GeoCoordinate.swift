//
//  GeoCoordinate.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import Foundation

struct GeoCoordinate: Equatable {
    var latitude: Double
    var longitude: Double

    init?(latitude: Double, longitude: Double) {
        guard latitude.isFinite, longitude.isFinite else { return nil }
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        self.latitude = latitude
        self.longitude = longitude
    }
}
