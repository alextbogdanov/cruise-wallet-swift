//
//  Routes.swift
//  CruiseWallet
//
//  Value-based navigation routes for the Home stack. Using distinct wrapper types
//  (rather than pushing `Sailing` for everything) lets the Voyage tab deep-link the
//  Ship and full Itinerary screens cleanly — and lets the DEBUG launch hooks build
//  an arbitrary path for sim screenshots.
//

import Foundation

struct ShipRoute: Hashable { let sailing: Sailing }
struct ItineraryRoute: Hashable { let sailing: Sailing }
