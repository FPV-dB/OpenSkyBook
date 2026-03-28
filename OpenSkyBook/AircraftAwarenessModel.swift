import AppKit
import AVFoundation
import Combine
import CoreLocation
import MapKit
import simd
import SwiftUI

enum MapOrientationMode: String, CaseIterable, Identifiable {
    case northUp
    case headingUp

    var id: String { rawValue }

    var label: String {
        switch self {
        case .northUp:
            "North-up"
        case .headingUp:
            "Heading-up"
        }
    }
}

enum HeadingSource: String {
    case compass
    case gpsCourse
    case unavailable

    var label: String {
        switch self {
        case .compass:
            "Compass active"
        case .gpsCourse:
            "GPS heading"
        case .unavailable:
            "No heading (map orientation only)"
        }
    }
}

enum HeadingAvailability {
    case compassActive
    case gpsHeading
    case waitingForSensor
    case stationaryNoCourse
    case mapAligned
    case hidden

    var statusText: String {
        switch self {
        case .compassActive:
            "Compass active"
        case .gpsHeading:
            "GPS heading"
        case .waitingForSensor:
            "Waiting for heading sensor"
        case .stationaryNoCourse:
            "No compass heading. Move to derive GPS course."
        case .mapAligned:
            "No heading (map orientation only)"
        case .hidden:
            "Heading display disabled"
        }
    }
}

enum DataSourcePreference: String, CaseIterable, Identifiable {
    case automatic
    case sdrOnly
    case networkOnly
    case combined

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic:
            "Auto"
        case .sdrOnly:
            "SDR"
        case .networkOnly:
            "Network"
        case .combined:
            "Combined"
        }
    }
}

enum MapPresentation: String, CaseIterable, Identifiable {
    case street
    case satellite
    case topographic
    case terrain

    var id: String { rawValue }

    var label: String {
        switch self {
        case .street:
            "Street"
        case .satellite:
            "Satellite"
        case .topographic:
            "Topographic"
        case .terrain:
            "Terrain"
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .street:
            .standard
        case .satellite:
            .imagery
        case .topographic:
            .standard(elevation: .realistic, emphasis: .muted, showsTraffic: false)
        case .terrain:
            .imagery(elevation: .realistic)
        }
    }
}

enum LocationSourcePreference: String, CaseIterable, Identifiable {
    case deviceGPS
    case manualCoordinates

    var id: String { rawValue }

    var label: String {
        switch self {
        case .deviceGPS:
            "Device GPS"
        case .manualCoordinates:
            "Manual"
        }
    }
}

enum FeedKind: String {
    case sdr
    case network

    var label: String {
        switch self {
        case .sdr:
            "SDR"
        case .network:
            "Network"
        }
    }
}

struct AircraftContact: Identifiable {
    let icao: String
    let callsign: String?
    let coordinate: CLLocationCoordinate2D
    let heading: Double
    let speedKnots: Double
    let altitudeFeetMSL: Double
    let source: FeedKind
    let lastSeen: Date

    var id: String { icao }
}

struct FeedSnapshot {
    let contacts: [AircraftContact]
    let fetchedAt: Date
    let detail: String
}

struct AircraftPresentation: Identifiable {
    let contact: AircraftContact
    let distanceMeters: CLLocationDistance
    let relativeAltitudeFeet: Double
    let relativeBearingDegrees: Double?
    let isAhead: Bool
    let isApproaching: Bool
    let isDescending: Bool
    let urgencyScore: Double
    let isAlerting: Bool
    let isEmphasized: Bool

    var id: String { contact.id }
    var coordinate: CLLocationCoordinate2D { contact.coordinate }
    var displayName: String {
        if let callsign = contact.callsign, !callsign.isEmpty {
            return callsign
        }
        return contact.icao.uppercased()
    }
    var heading: Double { contact.heading }
    var speedKnots: Double { contact.speedKnots }
    var distanceKilometers: Double { distanceMeters / 1_000 }
    var sourceLabel: String { contact.source.label }
    var relativeBearingSummary: String {
        guard let relativeBearingDegrees else { return "Relative bearing unavailable" }
        let rounded = Int(relativeBearingDegrees.rounded())
        switch rounded {
        case 0 ..< 15, 345 ... 360:
            return "Ahead"
        case 15 ..< 60:
            return "Front-right"
        case 60 ..< 120:
            return "Right"
        case 120 ..< 165:
            return "Rear-right"
        case 165 ..< 195:
            return "Behind"
        case 195 ..< 240:
            return "Rear-left"
        case 240 ..< 300:
            return "Left"
        default:
            return "Front-left"
        }
    }
}

enum TrafficAlertMode: String, CaseIterable, Identifiable {
    case tone
    case voice
    case toneAndVoice

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tone:
            "Tone"
        case .voice:
            "Voice"
        case .toneAndVoice:
            "Both"
        }
    }
}

enum TrafficAlertSensitivity: String, CaseIterable, Identifiable {
    case low
    case balanced
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low:
            "Low"
        case .balanced:
            "Balanced"
        case .high:
            "High"
        }
    }

    var cooldownSeconds: TimeInterval {
        switch self {
        case .low:
            24
        case .balanced:
            14
        case .high:
            8
        }
    }
}

enum TrafficAlertSound: String, CaseIterable, Identifiable {
    case glass
    case hero
    case sonar
    case submarine
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .glass:
            "Glass"
        case .hero:
            "Hero"
        case .sonar:
            "Sonar"
        case .submarine:
            "Submarine"
        case .custom:
            "Custom File"
        }
    }

    var soundName: NSSound.Name? {
        switch self {
        case .glass:
            NSSound.Name("Glass")
        case .hero:
            NSSound.Name("Hero")
        case .sonar:
            NSSound.Name("Sonar")
        case .submarine:
            NSSound.Name("Submarine")
        case .custom:
            nil
        }
    }
}

private struct TrafficTrackSnapshot {
    let distanceMeters: Double
    let relativeAltitudeFeet: Double
    let timestamp: Date
}

struct DeviceHeading {
    let trueHeadingDegrees: Double
    let headingAccuracyDegrees: Double?
    let source: HeadingSource
    let timestamp: Date

    var directionLabel: String {
        Self.compassPoint(for: trueHeadingDegrees)
    }

    var displayDegrees: Int {
        Int(trueHeadingDegrees.rounded())
    }

    var isReliable: Bool {
        guard let headingAccuracyDegrees else { return source == .gpsCourse }
        return headingAccuracyDegrees >= 0 && headingAccuracyDegrees <= 25
    }

    private static func compassPoint(for degrees: Double) -> String {
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        let adjusted = normalized >= 0 ? normalized : normalized + 360
        let sectors = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
        return sectors[Int((adjusted + 22.5) / 45)]
    }
}

struct WindEstimate {
    let speedKilometersPerHour: Double
    let gustKilometersPerHour: Double?
    let directionDegrees: Double
    let fetchedAt: Date

    var directionCompass: String {
        let normalized = directionDegrees.truncatingRemainder(dividingBy: 360)
        let adjusted = normalized >= 0 ? normalized : normalized + 360
        let sectors = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
        return sectors[Int((adjusted + 22.5) / 45)]
    }
}

struct AtmosphericCondition {
    let temperatureCelsius: Double?
    let pressureHectopascals: Double?
    let humidityPercent: Double?
    let precipitationMillimeters: Double?
    let precipitationProbabilityPercent: Double?
    let cloudCoverPercent: Double?
    let visibilityKilometers: Double?
    let weatherCode: Int?
    let fetchedAt: Date
    let trendSummary: String
}

enum MapOverlayKind: String, CaseIterable, Identifiable {
    case airspace
    case adsbTraffic
    case powerInfrastructure
    case weather
    case wind
    case fireDetection
    case notam
    case terrainElevation
    case landUse

    var id: String { rawValue }

    var label: String {
        switch self {
        case .airspace:
            "Airspace"
        case .adsbTraffic:
            "ADS-B Traffic"
        case .powerInfrastructure:
            "Power Infrastructure"
        case .weather:
            "Weather"
        case .wind:
            "Wind"
        case .fireDetection:
            "Fire Detection"
        case .notam:
            "NOTAM"
        case .terrainElevation:
            "Terrain / Elevation"
        case .landUse:
            "Land Use"
        }
    }

    var advisoryNote: String {
        switch self {
        case .airspace:
            "Advisory data only. Controlled airspace feed not configured."
        case .adsbTraffic:
            "Advisory data only. Traffic may be delayed or incomplete."
        case .powerInfrastructure:
            "Advisory data only. Verify lines and towers visually."
        case .weather:
            "Advisory data only. Weather overlay is model-derived."
        case .wind:
            "Advisory data only. Wind field is estimated from weather data."
        case .fireDetection:
            "Advisory data only. FIRMS detections can be delayed."
        case .notam:
            "Advisory data only. Always verify against official NOTAM sources."
        case .terrainElevation:
            "Advisory data only. Elevation overlay needs a DEM source."
        case .landUse:
            "Advisory data only. Land-use feed not configured."
        }
    }

    var defaultOpacity: Double {
        switch self {
        case .airspace:
            0.22
        case .adsbTraffic:
            1
        case .powerInfrastructure:
            0.9
        case .weather:
            0.5
        case .wind:
            0.9
        case .fireDetection:
            0.92
        case .notam:
            0.72
        case .terrainElevation:
            0.4
        case .landUse:
            0.3
        }
    }

    var defaultOrder: Int {
        switch self {
        case .terrainElevation:
            0
        case .landUse:
            1
        case .airspace:
            2
        case .weather:
            3
        case .powerInfrastructure:
            4
        case .notam:
            5
        case .fireDetection:
            6
        case .wind:
            7
        case .adsbTraffic:
            8
        }
    }
}

struct MapLayerConfiguration: Identifiable, Equatable {
    let kind: MapOverlayKind
    var isVisible: Bool
    var opacity: Double
    var order: Int
    var isSupported: Bool

    var id: MapOverlayKind { kind }
}

enum LayerPresetMode: String, CaseIterable, Identifiable {
    case preflight
    case flight
    case planning

    var id: String { rawValue }

    var label: String {
        switch self {
        case .preflight:
            "Preflight Mode"
        case .flight:
            "Flight Mode"
        case .planning:
            "Planning Mode"
        }
    }
}

enum SafetyRiskBand {
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .low:
            "LOW RISK"
        case .medium:
            "MEDIUM RISK"
        case .high:
            "HIGH RISK"
        }
    }

    var symbol: String {
        switch self {
        case .low:
            "circle.fill"
        case .medium:
            "exclamationmark.circle.fill"
        case .high:
            "exclamationmark.triangle.fill"
        }
    }
}

struct SafetyRiskFactor: Identifiable {
    let id: String
    let title: String
    let score: Double
    let weight: Double
    let detail: String
    let isAvailable: Bool
}

struct SafetyChecklistItem: Identifiable {
    let id: String
    let title: String
    let isComplete: Bool
    let detail: String
}

struct SafetyAssessment {
    let score: Int
    let band: SafetyRiskBand
    let factors: [SafetyRiskFactor]
    let checklist: [SafetyChecklistItem]
    let prioritizedAlerts: [String]
    let changes: [String]
    let readyToFly: Bool
    let readinessText: String
    let terrainStatus: String
    let signalStatus: String
    let rthStatus: String
    let lightStatus: String
    let geofenceStatus: String
    let safeFlightRadiusMeters: Double

    static let empty = SafetyAssessment(
        score: 0,
        band: .low,
        factors: [],
        checklist: [],
        prioritizedAlerts: [],
        changes: [],
        readyToFly: false,
        readinessText: "Awaiting safety data",
        terrainStatus: "Terrain assessment unavailable",
        signalStatus: "Signal assessment unavailable",
        rthStatus: "RTH assessment unavailable",
        lightStatus: "Light assessment unavailable",
        geofenceStatus: "Geofence advisory off",
        safeFlightRadiusMeters: 0
    )
}

enum PowerLineCategory: String {
    case transmission
    case distribution

    var label: String {
        switch self {
        case .transmission:
            "Transmission"
        case .distribution:
            "Distribution"
        }
    }
}

struct PowerLineFeature: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let category: PowerLineCategory
    let source: String
}

struct PowerStructure: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let kind: String
    let source: String
}

struct PowerInfrastructureSnapshot {
    let lines: [PowerLineFeature]
    let structures: [PowerStructure]
    let status: String
}

struct PowerDatasetConfiguration {
    enum Format {
        case geoJSON
        case kml

        nonisolated init?(value: String) {
            switch value.lowercased() {
            case "geojson", "json":
                self = .geoJSON
            case "kml":
                self = .kml
            default:
                return nil
            }
        }
    }

    let name: String
    let url: URL
    let format: Format
    let defaultCategory: PowerLineCategory
}

enum FireRecencyFilter: String, CaseIterable, Identifiable {
    case oneHour
    case sixHours
    case twentyFourHours

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneHour:
            "1h"
        case .sixHours:
            "6h"
        case .twentyFourHours:
            "24h"
        }
    }

    var maximumAge: TimeInterval {
        switch self {
        case .oneHour:
            3_600
        case .sixHours:
            21_600
        case .twentyFourHours:
            86_400
        }
    }
}

enum FireConfidenceLevel: Int, CaseIterable, Identifiable, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .low:
            "Low+"
        case .medium:
            "Med+"
        case .high:
            "High"
        }
    }

    static func < (lhs: FireConfidenceLevel, rhs: FireConfidenceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct FireDetection: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let detectedAt: Date
    let source: String
    let confidence: FireConfidenceLevel
    let brightness: Double?
    let frp: Double?
}

enum NotamDisplayMode: String, CaseIterable, Identifiable {
    case relevantOnly
    case showAll

    var id: String { rawValue }

    var label: String {
        switch self {
        case .relevantOnly:
            "Relevant"
        case .showAll:
            "All"
        }
    }
}

enum NotamKind: String {
    case restricted
    case hazard
    case airspaceChange
    case caution

    var label: String {
        switch self {
        case .restricted:
            "Restricted"
        case .hazard:
            "Hazard"
        case .airspaceChange:
            "Airspace"
        case .caution:
            "Caution"
        }
    }
}

enum NotamGeometry: Identifiable {
    case circle(center: CLLocationCoordinate2D, radiusMeters: Double)
    case polygon(coordinates: [CLLocationCoordinate2D])

    var id: String {
        switch self {
        case let .circle(center, radiusMeters):
            return "circle-\(center.latitude)-\(center.longitude)-\(radiusMeters)"
        case let .polygon(coordinates):
            return "polygon-\(coordinates.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";"))"
        }
    }
}

struct NotamAltitudeBand {
    let lowerFeet: Double?
    let upperFeet: Double?

    func intersects(plannedAltitudeFeet: Double) -> Bool {
        let lower = lowerFeet ?? 0
        let upper = upperFeet ?? 100_000
        return plannedAltitudeFeet >= lower && plannedAltitudeFeet <= upper
    }

    var label: String {
        let lower = lowerFeet.map { "\($0.cleanFeetDisplayLabel)" } ?? "SFC"
        let upper = upperFeet.map { "\($0.cleanFeetDisplayLabel)" } ?? "UNL"
        return "\(lower) to \(upper)"
    }
}

struct StructuredNOTAM: Identifiable {
    let id: String
    let reference: String
    let kind: NotamKind
    let geometry: NotamGeometry?
    let altitudeBand: NotamAltitudeBand
    let validFrom: Date?
    let validUntil: Date?
    let originalText: String
    let summary: String

    var isActive: Bool {
        let now = Date()
        let starts = validFrom ?? .distantPast
        let ends = validUntil ?? .distantFuture
        return starts <= now && now <= ends
    }

    var isUpcoming: Bool {
        guard let validFrom else { return false }
        let now = Date()
        return validFrom > now && validFrom.timeIntervalSince(now) <= 6 * 3_600
    }
}

@MainActor
final class AircraftAwarenessModel: ObservableObject {
    @Published var sourcePreference: DataSourcePreference = .automatic {
        didSet { rebuildPresentation() }
    }
    @Published var mapPresentation: MapPresentation = .street
    @Published var startupPreset: LayerPresetMode = .preflight
    @Published var selectedPreset: LayerPresetMode = .preflight
    @Published var isQuickLayersExpanded = false
    @Published var isCleanModeEnabled = false
    @Published var showAdvancedSafetyWeights = false
    @Published var mapOrientationMode: MapOrientationMode = .northUp {
        didSet {
            if mapOrientationMode == .headingUp, !hasReliableHeading {
                mapOrientationMode = .northUp
                return
            }
            applyCameraOrientationIfNeeded()
        }
    }
    @Published var layerConfigurations: [MapLayerConfiguration] = [
        MapLayerConfiguration(kind: .terrainElevation, isVisible: false, opacity: MapOverlayKind.terrainElevation.defaultOpacity, order: MapOverlayKind.terrainElevation.defaultOrder, isSupported: false),
        MapLayerConfiguration(kind: .landUse, isVisible: false, opacity: MapOverlayKind.landUse.defaultOpacity, order: MapOverlayKind.landUse.defaultOrder, isSupported: false),
        MapLayerConfiguration(kind: .airspace, isVisible: false, opacity: MapOverlayKind.airspace.defaultOpacity, order: MapOverlayKind.airspace.defaultOrder, isSupported: false),
        MapLayerConfiguration(kind: .weather, isVisible: false, opacity: MapOverlayKind.weather.defaultOpacity, order: MapOverlayKind.weather.defaultOrder, isSupported: true),
        MapLayerConfiguration(kind: .powerInfrastructure, isVisible: false, opacity: MapOverlayKind.powerInfrastructure.defaultOpacity, order: MapOverlayKind.powerInfrastructure.defaultOrder, isSupported: true),
        MapLayerConfiguration(kind: .notam, isVisible: false, opacity: MapOverlayKind.notam.defaultOpacity, order: MapOverlayKind.notam.defaultOrder, isSupported: true),
        MapLayerConfiguration(kind: .fireDetection, isVisible: false, opacity: MapOverlayKind.fireDetection.defaultOpacity, order: MapOverlayKind.fireDetection.defaultOrder, isSupported: true),
        MapLayerConfiguration(kind: .wind, isVisible: true, opacity: MapOverlayKind.wind.defaultOpacity, order: MapOverlayKind.wind.defaultOrder, isSupported: true),
        MapLayerConfiguration(kind: .adsbTraffic, isVisible: true, opacity: MapOverlayKind.adsbTraffic.defaultOpacity, order: MapOverlayKind.adsbTraffic.defaultOrder, isSupported: true)
    ]
    @Published var altitudeThresholdFeet: Double = 1_500 {
        didSet { rebuildPresentation() }
    }
    @Published var alertRadiusKilometers: Double = 5 {
        didSet { rebuildPresentation() }
    }
    @Published var hideHighAltitudeTraffic = false {
        didSet { rebuildPresentation() }
    }
    @Published var audioAlertsEnabled = true
    @Published var trafficAlertDistanceKilometers: Double = 3 {
        didSet { rebuildPresentation() }
    }
    @Published var trafficAlertAltitudeFeet: Double = 1_500 {
        didSet { rebuildPresentation() }
    }
    @Published var requireApproachingTraffic = false {
        didSet { rebuildPresentation() }
    }
    @Published var requireDescendingTraffic = false {
        didSet { rebuildPresentation() }
    }
    @Published var voiceAlertsEnabled = false
    @Published var trafficAlertMode: TrafficAlertMode = .toneAndVoice
    @Published var trafficAlertSensitivity: TrafficAlertSensitivity = .balanced
    @Published var trafficAlertSound: TrafficAlertSound = .hero
    @Published var customTrafficAlertSoundPath = ""
    @Published var trafficAlertVolume: Double = 0.8
    @Published var followUser = true
    @Published var locationSourcePreference: LocationSourcePreference = .deviceGPS {
        didSet {
            syncLocationSource()
            rebuildPresentation()
        }
    }
    @Published var manualLatitude = ""
    @Published var manualLongitude = ""
    @Published var manualCoordinateSummary = "Manual coordinates not set"
    @Published var showWindPanel = true
    @Published var showHeadingDisplay = true {
        didSet { refreshHeadingAvailability() }
    }
    @Published var headingEstimate: DeviceHeading?
    @Published var headingStatus = "Waiting for heading sensor"
    @Published var headingCalibrationMessage: String?
    @Published var headingSmoothingFactor: Double = 0.72
    @Published var showWindOverlay = true {
        didSet {
            guard !isSyncingLayerFlags else { return }
            syncLayerConfiguration(.wind, isVisible: showWindOverlay)
        }
    }
    @Published var windEstimate: WindEstimate?
    @Published var windStatus = "Waiting for weather data"
    @Published var showWeatherPanel = true
    @Published var showWeatherOverlay = false {
        didSet {
            guard !isSyncingLayerFlags else { return }
            syncLayerConfiguration(.weather, isVisible: showWeatherOverlay)
        }
    }
    @Published var weatherCondition: AtmosphericCondition?
    @Published var weatherStatus = "Waiting for atmospheric data"
    @Published var showTemperature = true
    @Published var showPressure = true
    @Published var showHumidity = true
    @Published var showPrecipitation = true
    @Published var showCloudCover = true
    @Published var showVisibility = true
    @Published var weatherHighWindThresholdKilometersPerHour: Double = 30 {
        didSet { rebuildWeatherWarnings() }
    }
    @Published var weatherRainThresholdMillimeters: Double = 0.2 {
        didSet { rebuildWeatherWarnings() }
    }
    @Published var weatherLowVisibilityThresholdKilometers: Double = 5 {
        didSet { rebuildWeatherWarnings() }
    }
    @Published var weatherAudioAlertsEnabled = true
    @Published var weatherWarningMessage: String?
    @Published var showTrafficLayer = true {
        didSet {
            guard !isSyncingLayerFlags else { return }
            rebuildPresentation()
            syncLayerConfiguration(.adsbTraffic, isVisible: showTrafficLayer)
        }
    }
    @Published var showPowerInfrastructure = false {
        didSet {
            guard !isSyncingLayerFlags else { return }
            syncLayerConfiguration(.powerInfrastructure, isVisible: showPowerInfrastructure)
            if showPowerInfrastructure {
                refreshPowerInfrastructure()
            } else {
                powerWarningMessage = nil
            }
        }
    }
    @Published var showPowerStructures = true
    @Published var powerBufferMeters: Double = 30 {
        didSet { rebuildPowerWarnings() }
    }
    @Published var powerAudioAlertsEnabled = true
    @Published var projectedFlightPathEnabled = false {
        didSet { rebuildPowerWarnings() }
    }
    @Published var projectedFlightDistanceMeters: Double = 250 {
        didSet { rebuildPowerWarnings() }
    }
    @Published var projectedFlightBearingDegrees: Double = 0 {
        didSet { rebuildPowerWarnings() }
    }
    @Published var powerLines: [PowerLineFeature] = []
    @Published var powerStructures: [PowerStructure] = []
    @Published var powerStatus = "Power infrastructure layer off"
    @Published var powerWarningMessage: String?
    @Published var showFireLayer = false {
        didSet {
            guard !isSyncingLayerFlags else { return }
            if showFireLayer {
                refreshFireDetections()
            } else {
                fireWarningMessage = nil
            }
        }
    }
    @Published var fireAlertRadiusKilometers: Double = 5 {
        didSet { rebuildFireWarnings() }
    }
    @Published var fireRecencyFilter: FireRecencyFilter = .sixHours {
        didSet {
            filterFireDetections()
            refreshFireDetections()
        }
    }
    @Published var minimumFireConfidence: FireConfidenceLevel = .medium {
        didSet { filterFireDetections() }
    }
    @Published var fireAudioAlertsEnabled = true
    @Published var showFireDetails = true
    @Published var fireDetections: [FireDetection] = []
    @Published var fireStatus = "Fire layer off"
    @Published var fireWarningMessage: String?
    @Published var showNotamLayer = false {
        didSet {
            guard !isSyncingLayerFlags else { return }
            syncLayerConfiguration(.notam, isVisible: showNotamLayer)
            if showNotamLayer {
                refreshAutomatedNOTAMs()
                filterNOTAMs()
            } else {
                notamWarningMessage = nil
            }
        }
    }
    @Published var notamDisplayMode: NotamDisplayMode = .relevantOnly {
        didSet { filterNOTAMs() }
    }
    @Published var notamAlertRadiusKilometers: Double = 20 {
        didSet { filterNOTAMs() }
    }
    @Published var notamAltitudeThresholdFeet: Double = 5_000 {
        didSet { filterNOTAMs() }
    }
    @Published var notamPlannedAltitudeFeet: Double = 400 {
        didSet { filterNOTAMs() }
    }
    @Published var notamAudioAlertsEnabled = true
    @Published var notamRawInput = ""
    @Published var notamStatus = "NOTAM layer off"
    @Published var parsedNOTAMs: [StructuredNOTAM] = []
    @Published var visibleNOTAMs: [StructuredNOTAM] = []
    @Published var notamWarningMessage: String?
    @Published var displayedAircraft: [AircraftPresentation] = []
    @Published var alertingAircraft: [AircraftPresentation] = []
    @Published var quickLayerOpacity: Double = 0.9
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var userCoordinate: CLLocationCoordinate2D?
    @Published var activeSourceStatus = "Waiting for feed"
    @Published var sourceHealthSummary = "Searching for local SDR decoder"
    @Published var sourceDetail = "Local RTL-SDR decoders are checked first. Network polling starts when local data is unavailable."
    @Published var primaryAlertMessage: String?
    @Published var locationSummary = "Locating user"
    @Published var trafficAlertStatus = "Traffic alert monitoring active"
    @Published var trafficAlertDisclaimer = "Not all aircraft broadcast ADS-B – maintain visual awareness"
    @Published private(set) var headingAvailability: HeadingAvailability = .waitingForSensor
    @Published var telemetrySignalAvailable = false {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var telemetryBatteryAvailable = false {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var telemetryBatteryPercent: Double = 80 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var telemetryRSSI: Double = -67 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var telemetryLinkQualityPercent: Double = 92 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var droneAltitudeFeet: Double = 400 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var rthAltitudeFeet: Double = 250 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var terrainSafetyMarginFeet: Double = 120 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var geofenceEnabled = false {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var geofenceRadiusKilometers: Double = 2 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var notamReviewedForChecklist = false {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var weightWind: Double = 1 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var weightTraffic: Double = 1.4 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var weightAirspace: Double = 0.8 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var weightNOTAM: Double = 1.2 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var weightTerrain: Double = 1 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var weightSignal: Double = 0.9 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published var weightWeather: Double = 1.1 {
        didSet { rebuildSafetyAssessment() }
    }
    @Published private(set) var safetyAssessment: SafetyAssessment = .empty
    @Published var airspaceStatus = "Airspace layer unavailable"
    @Published var landUseStatus = "Land-use layer unavailable"
    @Published var terrainStatus = "Terrain overlay unavailable"

    let locationMonitor: LocationMonitor

    var alertRadiusMeters: CLLocationDistance { alertRadiusKilometers * 1_000 }
    var orderedLayerConfigurations: [MapLayerConfiguration] { layerConfigurations.sorted { $0.order < $1.order } }
    var visibleLayerCount: Int { layerConfigurations.filter(\.isVisible).count }
    var renderedAircraft: [AircraftPresentation] { showTrafficLayer ? displayedAircraft : [] }
    var quickToggleKinds: [MapOverlayKind] { [.adsbTraffic, .airspace, .notam, .weather, .wind, .powerInfrastructure, .fireDetection] }
    var nonEssentialOverlayKinds: Set<MapOverlayKind> { [.airspace, .weather, .wind, .powerInfrastructure, .fireDetection, .landUse, .terrainElevation, .notam] }
    var environmentalOverlayKinds: Set<MapOverlayKind> { [.weather, .wind, .landUse, .terrainElevation] }
    var showAlertFirstSuppression: Bool { primaryAlertMessage != nil || notamWarningMessage != nil }
    var effectiveVisibleLayerCount: Int { orderedLayerConfigurations.filter { effectiveLayerVisibility(for: $0.kind) }.count }
    var headingStatusIndicator: String { headingSourceSummary }
    var alertStatusIndicator: String { primaryAlertMessage == nil ? "Clear" : "Alert" }
    var hasReliableHeading: Bool {
        guard let headingEstimate else { return false }
        switch headingEstimate.source {
        case .compass:
            return headingEstimate.isReliable
        case .gpsCourse:
            return true
        case .unavailable:
            return false
        }
    }
    var headingDegrees: Double? { hasReliableHeading ? headingEstimate?.trueHeadingDegrees : nil }
    var effectiveReferenceHeadingDegrees: Double { headingDegrees ?? 0 }
    var isUsingMapOrientationFallback: Bool { headingDegrees == nil }
    var headingDisplayText: String {
        guard showHeadingDisplay else { return "Heading hidden" }
        guard headingDegrees != nil else { return "N/A" }
        guard let headingEstimate else { return "N/A" }
        return "\(headingEstimate.displayDegrees)° \(headingEstimate.directionLabel)"
    }
    var headingSourceSummary: String {
        if let headingEstimate, hasReliableHeading {
            return headingEstimate.source.label
        }
        return HeadingSource.unavailable.label
    }
    var trafficAlertRadiusMeters: Double { trafficAlertDistanceKilometers * 1_000 }
    var effectiveTrafficAlertMode: TrafficAlertMode {
        switch trafficAlertMode {
        case .tone:
            .tone
        case .voice:
            voiceAlertsEnabled ? .voice : .tone
        case .toneAndVoice:
            voiceAlertsEnabled ? .toneAndVoice : .tone
        }
    }
    var droneHeadingDegrees: Double? { projectedFlightPathEnabled ? projectedFlightBearingDegrees : nil }
    var headingFallbackSummary: String {
        isUsingMapOrientationFallback ? "North-up fallback active. Map-up defines forward." : "Directional features use live heading data"
    }
    var headingComparisonSummary: String {
        if let headingDegrees {
            guard let droneHeadingDegrees else { return "Drone heading unavailable" }
            let offset = Self.normalizedAngle(droneHeadingDegrees - headingDegrees)
            return "User \(Int(headingDegrees.rounded()))° vs drone \(Int(droneHeadingDegrees.rounded()))° • Δ\(Int(offset.rounded()))°"
        }
        if let droneHeadingDegrees {
            return "No user heading. Drone heading is \(Int(droneHeadingDegrees.rounded()))°"
        }
        return "Map-aligned only"
    }
    var layerDensityWarning: String? {
        effectiveVisibleLayerCount > 5 ? "Layer density reduced. Disable low-priority overlays to declutter the map." : nil
    }
    var headingConeCoordinates: [CLLocationCoordinate2D] {
        guard showHeadingDisplay, let coordinate = userCoordinate, let headingDegrees else { return [] }
        let left = Self.destinationCoordinate(from: coordinate, distanceMeters: 350, bearingDegrees: headingDegrees - 18)
        let center = Self.destinationCoordinate(from: coordinate, distanceMeters: 700, bearingDegrees: headingDegrees)
        let right = Self.destinationCoordinate(from: coordinate, distanceMeters: 350, bearingDegrees: headingDegrees + 18)
        return [coordinate, left, center, right]
    }
    var isZoomedOut: Bool { (visibleRegion?.span.latitudeDelta ?? 0) > 8 }

    private let localProvider = LocalSDRProvider()
    private let networkProvider = OpenSkyNetworkProvider()
    private let atmosphereProvider = AtmosphericWeatherProvider()
    private let powerProvider = PowerInfrastructureProvider()
    private let fireProvider = FIRMSFireProvider()
    private let notamProvider = NAIPSNotamProvider()
    private var localSnapshot: FeedSnapshot?
    private var networkSnapshot: FeedSnapshot?
    private var deviceLocation: CLLocation?
    private var manualLocation: CLLocation?
    private var refreshTasks: [Task<Void, Never>] = []
    private var recentAlertTimes: [String: Date] = [:]
    private var previousTrafficSnapshots: [String: TrafficTrackSnapshot] = [:]
    private var recentPowerAlertAt: Date?
    private var recentFireAlertAt: Date?
    private var recentWeatherAlertAt: Date?
    private var recentNotamAlertAt: Date?
    private var visibleRegion: MKCoordinateRegion?
    private var savedLayerConfigurationsBeforeCleanMode: [MapLayerConfiguration]?
    private var isSyncingLayerFlags = false
    private var previousSafetyChangeState = (
        alertingAircraftIDs: Set<String>(),
        activeNotamIDs: Set<String>(),
        windSpeed: Optional<Double>.none,
        riskBand: SafetyRiskBand.low
    )
    private var powerFetchTask: Task<Void, Never>?
    private var fireFetchTask: Task<Void, Never>?
    private var rawFireDetections: [FireDetection] = []
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let isPreview: Bool

    @MainActor
    init(locationMonitor: LocationMonitor? = nil, isPreview: Bool = false) {
        let locationMonitor = locationMonitor ?? LocationMonitor()
        self.locationMonitor = locationMonitor
        self.isPreview = isPreview
        self.headingAvailability = locationMonitor.headingSupported ? .waitingForSensor : .mapAligned
        self.headingStatus = self.headingAvailability.statusText

        locationMonitor.onLocationUpdate = { [weak self] location in
            Task { @MainActor [weak self] in
                self?.updateLocation(location)
            }
        }
        locationMonitor.onHeadingUpdate = { [weak self] heading in
            Task { @MainActor [weak self] in
                self?.updateHeading(from: heading)
            }
        }
        locationMonitor.onHeadingFailure = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleHeadingFailure()
            }
        }

        if isPreview {
            seedPreviewState()
        } else {
            applyPreset(startupPreset)
            locationMonitor.start()
            startMonitoring()
            refreshHeadingAvailability()
        }
        rebuildSafetyAssessment()
    }

    deinit {
        refreshTasks.forEach { $0.cancel() }
        powerFetchTask?.cancel()
        fireFetchTask?.cancel()
    }

    func recenterOnUser() {
        guard let referenceLocation else { return }
        let region = Self.region(centeredOn: referenceLocation.coordinate, radiusMeters: max(alertRadiusMeters * 1.6, 6_000))
        visibleRegion = region
        applyCameraOrientationIfNeeded(region: region)
    }

    static var preview: AircraftAwarenessModel {
        AircraftAwarenessModel(isPreview: true)
    }

    var projectedFlightPathCoordinates: [CLLocationCoordinate2D] {
        guard projectedFlightPathEnabled, let start = userCoordinate else { return [] }
        return [start, Self.destinationCoordinate(from: start, distanceMeters: projectedFlightDistanceMeters, bearingDegrees: projectedFlightBearingDegrees)]
    }

    func parseManualNOTAMInput() {
        parsedNOTAMs = NOTAMParser.parse(rawText: notamRawInput)
        notamStatus = parsedNOTAMs.isEmpty ? "No parseable NOTAM areas found" : "Parsed \(parsedNOTAMs.count) NOTAMs from manual input"
        filterNOTAMs()
    }

    var powerDisclaimer: String {
        "Powerline data may be incomplete – always visually confirm"
    }

    var fireDisclaimer: String {
        "Satellite fire data may be delayed and approximate"
    }

    var weatherDisclaimer: String {
        "Weather data is estimated from nearby stations/models"
    }

    var notamDisclaimer: String {
        "NOTAM data is advisory – always verify via official sources (Airservices Australia)"
    }

    func setLayerVisibility(_ isVisible: Bool, for kind: MapOverlayKind) {
        if isCleanModeEnabled && isVisible {
            isCleanModeEnabled = false
            savedLayerConfigurationsBeforeCleanMode = nil
        }
        updateLayerConfiguration(for: kind) { configuration in
            configuration.isVisible = isVisible
        }

        switch kind {
        case .airspace:
            airspaceStatus = "Airspace layer unavailable"
        case .adsbTraffic:
            if showTrafficLayer != isVisible {
                showTrafficLayer = isVisible
            }
        case .powerInfrastructure:
            if showPowerInfrastructure != isVisible {
                showPowerInfrastructure = isVisible
            }
        case .weather:
            if showWeatherOverlay != isVisible {
                showWeatherOverlay = isVisible
            }
            if showWeatherPanel != isVisible {
                showWeatherPanel = isVisible
            }
        case .wind:
            if showWindOverlay != isVisible {
                showWindOverlay = isVisible
            }
            if showWindPanel != isVisible {
                showWindPanel = isVisible
            }
        case .fireDetection:
            if showFireLayer != isVisible {
                showFireLayer = isVisible
            }
        case .notam:
            if showNotamLayer != isVisible {
                showNotamLayer = isVisible
            }
        case .terrainElevation:
            terrainStatus = "Terrain overlay unavailable"
        case .landUse:
            landUseStatus = "Land-use layer unavailable"
        }
    }

    func setLayerOpacity(_ opacity: Double, for kind: MapOverlayKind) {
        updateLayerConfiguration(for: kind) { configuration in
            configuration.opacity = min(max(opacity, 0.15), 1)
        }
    }

    func moveLayer(_ kind: MapOverlayKind, direction: Int) {
        var ordered = orderedLayerConfigurations
        guard let index = ordered.firstIndex(where: { $0.kind == kind }) else { return }
        let destination = index + direction
        guard ordered.indices.contains(destination) else { return }
        ordered.swapAt(index, destination)
        layerConfigurations = ordered.enumerated().map { index, configuration in
            var updated = configuration
            updated.order = index
            return updated
        }
    }

    func applyPreset(_ preset: LayerPresetMode) {
        selectedPreset = preset
        isCleanModeEnabled = false
        savedLayerConfigurationsBeforeCleanMode = nil

        let visibleKinds: Set<MapOverlayKind>
        switch preset {
        case .preflight:
            visibleKinds = Set(MapOverlayKind.allCases.filter { configuration(for: $0).isSupported })
        case .flight:
            visibleKinds = [.adsbTraffic]
        case .planning:
            visibleKinds = [.airspace, .powerInfrastructure, .terrainElevation]
        }

        layerConfigurations = layerConfigurations.map { configuration in
            var updated = configuration
            if updated.isSupported {
                updated.isVisible = visibleKinds.contains(updated.kind)
            }
            return updated
        }
        syncFeatureFlagsFromLayerConfigurations()
    }

    func toggleCleanMode() {
        if isCleanModeEnabled {
            restoreOverlayStateAfterCleanMode()
            return
        }
        savedLayerConfigurationsBeforeCleanMode = layerConfigurations
        isCleanModeEnabled = true
        layerConfigurations = layerConfigurations.map { configuration in
            var updated = configuration
            updated.isVisible = updated.kind == .adsbTraffic ? configuration.isSupported : false
            return updated
        }
        syncFeatureFlagsFromLayerConfigurations()
    }

    func collapseOverlayState() {
        toggleCleanMode()
    }

    func restoreOverlayStateAfterCleanMode() {
        guard let savedLayerConfigurationsBeforeCleanMode else {
            isCleanModeEnabled = false
            return
        }
        layerConfigurations = savedLayerConfigurationsBeforeCleanMode
        self.savedLayerConfigurationsBeforeCleanMode = nil
        isCleanModeEnabled = false
        syncFeatureFlagsFromLayerConfigurations()
    }

    func toggleQuickLayersPanel() {
        isQuickLayersExpanded.toggle()
    }

    func effectiveLayerVisibility(for kind: MapOverlayKind) -> Bool {
        guard configuration(for: kind).isVisible else { return false }
        if isCleanModeEnabled {
            return kind == .adsbTraffic
        }
        if showAlertFirstSuppression, environmentalOverlayKinds.contains(kind) {
            return false
        }
        return true
    }

    func effectiveOpacity(for kind: MapOverlayKind) -> Double {
        let baseOpacity = opacity(for: kind) * quickLayerOpacity
        var adjustedOpacity = baseOpacity
        if effectiveVisibleLayerCount >= 4, environmentalOverlayKinds.contains(kind) {
            adjustedOpacity *= 0.6
        }
        if effectiveVisibleLayerCount >= 6, nonEssentialOverlayKinds.contains(kind) {
            adjustedOpacity *= 0.72
        }
        if isZoomedOut, kind == .notam || kind == .fireDetection {
            adjustedOpacity *= 0.75
        }
        return max(0.12, min(adjustedOpacity, 1))
    }

    func shouldShowLayerLabels(for kind: MapOverlayKind) -> Bool {
        !isZoomedOut && effectiveVisibleLayerCount < 5 && !showAlertFirstSuppression
    }

    func opacity(for kind: MapOverlayKind) -> Double {
        layerConfigurations.first(where: { $0.kind == kind })?.opacity ?? kind.defaultOpacity
    }

    func configuration(for kind: MapOverlayKind) -> MapLayerConfiguration {
        layerConfigurations.first(where: { $0.kind == kind }) ?? MapLayerConfiguration(
            kind: kind,
            isVisible: false,
            opacity: kind.defaultOpacity,
            order: kind.defaultOrder,
            isSupported: false
        )
    }

    func canMoveLayer(_ kind: MapOverlayKind, direction: Int) -> Bool {
        guard let index = orderedLayerConfigurations.firstIndex(where: { $0.kind == kind }) else { return false }
        return orderedLayerConfigurations.indices.contains(index + direction)
    }

    func detailVisibilityThreshold(for kind: MapOverlayKind) -> CLLocationDegrees {
        switch kind {
        case .powerInfrastructure:
            2
        case .fireDetection:
            6
        case .notam:
            18
        case .weather, .wind:
            12
        case .adsbTraffic:
            30
        case .airspace, .terrainElevation, .landUse:
            1.5
        }
    }

    func shouldRenderLayer(_ kind: MapOverlayKind) -> Bool {
        let configuration = configuration(for: kind)
        guard configuration.isVisible else { return false }
        if !configuration.isSupported {
            return false
        }
        guard let visibleRegion else { return true }
        return visibleRegion.span.latitudeDelta <= detailVisibilityThreshold(for: kind)
    }

    func layerStatus(for kind: MapOverlayKind) -> String {
        switch kind {
        case .airspace:
            airspaceStatus
        case .adsbTraffic:
            "\(renderedAircraft.count) aircraft in view"
        case .powerInfrastructure:
            powerStatus
        case .weather:
            weatherStatus
        case .wind:
            windStatus
        case .fireDetection:
            fireStatus
        case .notam:
            notamStatus
        case .terrainElevation:
            terrainStatus
        case .landUse:
            landUseStatus
        }
    }

    func applyManualCoordinates() {
        guard
            let latitude = Double(manualLatitude),
            let longitude = Double(manualLongitude),
            (-90 ... 90).contains(latitude),
            (-180 ... 180).contains(longitude)
        else {
            manualCoordinateSummary = "Enter valid latitude and longitude"
            return
        }

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: deviceLocation?.altitude ?? 0,
            horizontalAccuracy: 5,
            verticalAccuracy: -1,
            timestamp: .now
        )

        manualLocation = location
        manualCoordinateSummary = "Using \(Self.formatted(latitude, decimals: 4)), \(Self.formatted(longitude, decimals: 4))"

        if locationSourcePreference == .manualCoordinates {
            applyReferenceLocation(location)
            refreshAtmosphereNow()
            refreshPowerInfrastructure()
            refreshFireDetections()
            filterNOTAMs()
            rebuildSafetyAssessment()
        }
    }

    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
        if mapOrientationMode == .headingUp {
            applyCameraOrientationIfNeeded(region: region)
        }
        if showPowerInfrastructure {
            refreshPowerInfrastructure()
        }
        if showFireLayer {
            refreshFireDetections()
        }
        if showWeatherPanel {
            refreshAtmosphereNow()
        }
        if showNotamLayer {
            refreshAutomatedNOTAMs()
            filterNOTAMs()
        }
        rebuildSafetyAssessment()
    }

    private func updateLayerConfiguration(for kind: MapOverlayKind, mutate: (inout MapLayerConfiguration) -> Void) {
        guard let index = layerConfigurations.firstIndex(where: { $0.kind == kind }) else { return }
        var updated = layerConfigurations[index]
        mutate(&updated)
        layerConfigurations[index] = updated
        syncFeatureFlagsFromLayerConfigurations()
    }

    private func syncLayerConfiguration(_ kind: MapOverlayKind, isVisible: Bool) {
        updateLayerConfiguration(for: kind) { configuration in
            configuration.isVisible = isVisible
        }
    }

    private func syncFeatureFlagsFromLayerConfigurations() {
        isSyncingLayerFlags = true
        showTrafficLayer = configuration(for: .adsbTraffic).isVisible
        showWeatherOverlay = configuration(for: .weather).isVisible
        showWeatherPanel = configuration(for: .weather).isVisible
        showWindOverlay = configuration(for: .wind).isVisible
        showWindPanel = configuration(for: .wind).isVisible
        showPowerInfrastructure = configuration(for: .powerInfrastructure).isVisible
        showFireLayer = configuration(for: .fireDetection).isVisible
        showNotamLayer = configuration(for: .notam).isVisible
        isSyncingLayerFlags = false
    }

    private func updateLocation(_ location: CLLocation) {
        deviceLocation = location
        updateHeadingFromCourseIfNeeded(location)
        refreshHeadingAvailability()
        if locationSourcePreference == .deviceGPS {
            applyReferenceLocation(location)
        }
    }

    private func applyReferenceLocation(_ location: CLLocation) {
        userCoordinate = location.coordinate
        locationSummary = "\(Self.formatted(location.coordinate.latitude, decimals: 4)), \(Self.formatted(location.coordinate.longitude, decimals: 4))"

        if followUser || mapOrientationMode == .headingUp {
            let region = visibleRegion ?? Self.region(centeredOn: location.coordinate, radiusMeters: max(alertRadiusMeters * 1.6, 6_000))
            visibleRegion = region
            applyCameraOrientationIfNeeded(region: region)
        }

        rebuildPresentation()
        rebuildPowerWarnings()
        rebuildFireWarnings()
        rebuildWeatherWarnings()
        rebuildNOTAMWarnings()
    }

    private func startMonitoring() {
        refreshTasks = [
            Task { [weak self] in
                while let self, !Task.isCancelled {
                    let result = await self.localProvider.fetch()
                    await MainActor.run {
                        self.localSnapshot = result
                        self.rebuildPresentation()
                    }

                    try? await Task.sleep(for: .seconds(1))
                }
            },
            Task { [weak self] in
                while let self, !Task.isCancelled {
                    let result = await self.networkProvider.fetch(around: self.referenceLocation, radiusMeters: max(self.alertRadiusMeters * 3, 15_000))
                    await MainActor.run {
                        self.networkSnapshot = result
                        self.rebuildPresentation()
                    }

                    try? await Task.sleep(for: .seconds(4))
                }
            },
            Task { [weak self] in
                while let self, !Task.isCancelled {
                    let coordinate = await MainActor.run { self.referenceLocation?.coordinate }
                    let result = await self.atmosphereProvider.fetchAtmosphere(at: coordinate)
                    await MainActor.run {
                        self.windEstimate = result?.wind
                        self.windStatus = result?.windStatus ?? "Waiting for weather data"
                        self.weatherCondition = result?.condition
                        self.weatherStatus = result?.weatherStatus ?? "Waiting for atmospheric data"
                        self.rebuildWeatherWarnings()
                    }

                    try? await Task.sleep(for: .seconds(180))
                }
            }
        ]
    }

    private func rebuildPresentation() {
        let contacts = selectContacts()
        let presentations = buildPresentations(from: contacts)
        displayedAircraft = presentations
        alertingAircraft = presentations.filter(\.isAlerting)
        primaryAlertMessage = alertingAircraft.first.map {
            "\($0.displayName) is \(Self.formatted($0.distanceKilometers, decimals: 2)) km away at \(Int($0.relativeAltitudeFeet)) ft AGL."
        }
        if !audioAlertsEnabled {
            trafficAlertStatus = "Traffic audible alerts disabled"
        } else if alertingAircraft.isEmpty {
            trafficAlertStatus = "No traffic inside the configured alert zone"
        } else if let first = alertingAircraft.first {
            trafficAlertStatus = trafficAlertSummary(for: first)
        }

        if let referenceLocation {
            locationSummary = "\(Self.formatted(referenceLocation.coordinate.latitude, decimals: 4)), \(Self.formatted(referenceLocation.coordinate.longitude, decimals: 4))"
        }

        updateSourceStatus(with: contacts.count)
        playAlertIfNeeded(for: alertingAircraft)
        rebuildPowerWarnings()
        rebuildFireWarnings()
        rebuildWeatherWarnings()
        rebuildNOTAMWarnings()
        rebuildSafetyAssessment()
    }

    private func selectContacts() -> [AircraftContact] {
        let now = Date()
        let freshLocal = localSnapshot.flatMap { now.timeIntervalSince($0.fetchedAt) < 3 ? $0 : nil }
        let freshNetwork = networkSnapshot.flatMap { now.timeIntervalSince($0.fetchedAt) < 10 ? $0 : nil }

        switch sourcePreference {
        case .automatic:
            if let freshLocal, !freshLocal.contacts.isEmpty {
                return freshLocal.contacts
            }
            return freshNetwork?.contacts ?? []
        case .sdrOnly:
            return freshLocal?.contacts ?? []
        case .networkOnly:
            return freshNetwork?.contacts ?? []
        case .combined:
            return merge(local: freshLocal?.contacts ?? [], network: freshNetwork?.contacts ?? [])
        }
    }

    private func buildPresentations(from contacts: [AircraftContact]) -> [AircraftPresentation] {
        guard let referenceLocation else { return [] }

        let userAltitudeFeet = referenceLocation.altitude * 3.28084
        let now = Date()
        let referenceHeading = effectiveReferenceHeadingDegrees
        let canUseDirectionalPriority = hasReliableHeading

        return contacts.compactMap { contact in
            let aircraftLocation = CLLocation(latitude: contact.coordinate.latitude, longitude: contact.coordinate.longitude)
            let distance = aircraftLocation.distance(from: referenceLocation)
            let relativeAltitude = max(0, contact.altitudeFeetMSL - userAltitudeFeet)
            let previousSnapshot = previousTrafficSnapshots[contact.id]
            let approaching = previousSnapshot.map { distance < $0.distanceMeters - 40 } ?? false
            let descending = previousSnapshot.map { relativeAltitude < $0.relativeAltitudeFeet - 75 } ?? false
            let emphasized = relativeAltitude <= altitudeThresholdFeet || distance <= alertRadiusMeters
            let bearingToAircraft = Self.bearing(from: referenceLocation.coordinate, to: contact.coordinate)
            let relativeBearing: Double? = Self.normalizedAngle(bearingToAircraft - referenceHeading)
            let isAhead = relativeBearing.map { $0 <= 55 || $0 >= 305 } ?? false
            let meetsProximityThreshold = distance <= trafficAlertRadiusMeters && relativeAltitude <= trafficAlertAltitudeFeet
            let meetsTrendThreshold = (!requireApproachingTraffic || approaching) && (!requireDescendingTraffic || descending)
            let insideAlertBubble = meetsProximityThreshold && meetsTrendThreshold
            let urgency = Self.trafficUrgencyScore(
                distanceMeters: distance,
                relativeAltitudeFeet: relativeAltitude,
                isApproaching: approaching,
                isDescending: descending,
                isAhead: canUseDirectionalPriority ? isAhead : false
            )

            if hideHighAltitudeTraffic && !emphasized {
                return nil
            }

            previousTrafficSnapshots[contact.id] = TrafficTrackSnapshot(
                distanceMeters: distance,
                relativeAltitudeFeet: relativeAltitude,
                timestamp: now
            )

            return AircraftPresentation(
                contact: contact,
                distanceMeters: distance,
                relativeAltitudeFeet: relativeAltitude,
                relativeBearingDegrees: relativeBearing,
                isAhead: isAhead,
                isApproaching: approaching,
                isDescending: descending,
                urgencyScore: urgency,
                isAlerting: insideAlertBubble,
                isEmphasized: emphasized
            )
        }
        .sorted { lhs, rhs in
            if lhs.isAlerting != rhs.isAlerting {
                return lhs.isAlerting && !rhs.isAlerting
            }
            if lhs.urgencyScore != rhs.urgencyScore {
                return lhs.urgencyScore > rhs.urgencyScore
            }
            if canUseDirectionalPriority, lhs.isAhead != rhs.isAhead {
                return lhs.isAhead && !rhs.isAhead
            }
            if lhs.isEmphasized != rhs.isEmphasized {
                return lhs.isEmphasized && !rhs.isEmphasized
            }
            return lhs.distanceMeters < rhs.distanceMeters
        }
    }

    private func updateSourceStatus(with contactCount: Int) {
        let localDetail = localSnapshot?.detail ?? "No local SDR decoder detected"
        let networkDetail = networkSnapshot?.detail ?? "Network standby"
        sourceHealthSummary = "Local: \(localDetail) | Network: \(networkDetail)"

        switch sourcePreference {
        case .automatic:
            if let localSnapshot, Date().timeIntervalSince(localSnapshot.fetchedAt) < 3, !localSnapshot.contacts.isEmpty {
                activeSourceStatus = "Auto: SDR live (\(contactCount))"
                sourceDetail = localDetail
            } else if let networkSnapshot, Date().timeIntervalSince(networkSnapshot.fetchedAt) < 10, !networkSnapshot.contacts.isEmpty {
                activeSourceStatus = "Auto: Network fallback (\(contactCount))"
                sourceDetail = networkDetail
            } else {
                activeSourceStatus = "Auto: searching"
                sourceDetail = "Waiting for either a local decoder or a network response."
            }
        case .sdrOnly:
            activeSourceStatus = "SDR only (\(contactCount))"
            sourceDetail = localDetail
        case .networkOnly:
            activeSourceStatus = "Network only (\(contactCount))"
            sourceDetail = networkDetail
        case .combined:
            activeSourceStatus = "Combined (\(contactCount))"
            sourceDetail = "Local contacts override network duplicates."
        }
    }

    private func rebuildSafetyAssessment() {
        let windFactor = safetyWindFactor()
        let trafficFactor = safetyTrafficFactor()
        let airspaceFactor = safetyAirspaceFactor()
        let notamFactor = safetyNOTAMFactor()
        let terrainFactor = safetyTerrainFactor()
        let signalFactor = safetySignalFactor()
        let weatherFactor = safetyWeatherFactor()

        let factors = [windFactor, trafficFactor, airspaceFactor, notamFactor, terrainFactor, signalFactor, weatherFactor]
        let totalWeight = max(0.01, factors.reduce(0) { $0 + ($1.isAvailable ? $1.weight : 0) })
        let weightedScore = factors.reduce(0.0) { partial, factor in
            guard factor.isAvailable else { return partial }
            return partial + factor.score * factor.weight
        } / totalWeight
        let score = Int((weightedScore * 100).rounded())
        let band: SafetyRiskBand
        switch score {
        case 0 ..< 35:
            band = .low
        case 35 ..< 70:
            band = .medium
        default:
            band = .high
        }

        let safeRadiusMeters = estimatedSafeFlightRadiusMeters()
        let terrainStatus = terrainAdvisoryStatus()
        let signalStatus = signalAdvisoryStatus()
        let rthStatus = rthAdvisoryStatus(safeRadiusMeters: safeRadiusMeters)
        let lightStatus = lightAdvisoryStatus()
        let geofenceStatus = geofenceAdvisoryStatus()
        let checklist = preflightChecklist(
            windFactor: windFactor,
            trafficFactor: trafficFactor,
            notamFactor: notamFactor,
            signalFactor: signalFactor,
            weatherFactor: weatherFactor,
            safeRadiusMeters: safeRadiusMeters
        )
        let readyToFly = checklist.allSatisfy(\.isComplete)
        let readinessText = readyToFly ? "READY TO FLY" : "Review checklist before launch"
        let prioritizedAlerts = prioritizedSafetyAlerts(
            terrainStatus: terrainStatus,
            signalStatus: signalStatus,
            rthStatus: rthStatus,
            lightStatus: lightStatus,
            geofenceStatus: geofenceStatus
        )
        let changes = detectSafetyChanges(nextBand: band)

        safetyAssessment = SafetyAssessment(
            score: score,
            band: band,
            factors: factors,
            checklist: checklist,
            prioritizedAlerts: prioritizedAlerts,
            changes: changes,
            readyToFly: readyToFly,
            readinessText: readinessText,
            terrainStatus: terrainStatus,
            signalStatus: signalStatus,
            rthStatus: rthStatus,
            lightStatus: lightStatus,
            geofenceStatus: geofenceStatus,
            safeFlightRadiusMeters: safeRadiusMeters
        )
    }

    private func safetyWindFactor() -> SafetyRiskFactor {
        let weight = weightWind
        guard let windEstimate else {
            return SafetyRiskFactor(id: "wind", title: "Wind", score: 0, weight: weight, detail: "Wind estimate unavailable", isAvailable: false)
        }
        let gust = windEstimate.gustKilometersPerHour ?? windEstimate.speedKilometersPerHour
        let normalized = min(1, max(windEstimate.speedKilometersPerHour / 45, gust / 55))
        return SafetyRiskFactor(id: "wind", title: "Wind", score: normalized, weight: weight, detail: "\(Int(windEstimate.speedKilometersPerHour.rounded())) km/h, gust \(Int(gust.rounded()))", isAvailable: true)
    }

    private func safetyTrafficFactor() -> SafetyRiskFactor {
        let weight = weightTraffic
        guard let aircraft = alertingAircraft.first else {
            return SafetyRiskFactor(id: "traffic", title: "Aircraft", score: 0.05, weight: weight, detail: "No low-altitude aircraft inside alert zone", isAvailable: true)
        }
        let score = min(1, aircraft.urgencyScore + (alertingAircraft.count > 1 ? 0.15 : 0))
        return SafetyRiskFactor(id: "traffic", title: "Aircraft", score: score, weight: weight, detail: "\(aircraft.displayName) \(Self.formatted(aircraft.distanceKilometers, decimals: 1)) km / \(Int(aircraft.relativeAltitudeFeet)) ft", isAvailable: true)
    }

    private func safetyAirspaceFactor() -> SafetyRiskFactor {
        let weight = weightAirspace
        let airspaceNotams = visibleNOTAMs.filter { $0.kind == .airspaceChange && ($0.isActive || $0.isUpcoming) }
        guard !airspaceNotams.isEmpty else {
            return SafetyRiskFactor(id: "airspace", title: "Airspace", score: 0, weight: weight, detail: "No configured controlled airspace feed", isAvailable: false)
        }
        let activeCount = airspaceNotams.filter(\.isActive).count
        let score = min(1, Double(activeCount) * 0.45 + (airspaceNotams.contains(where: \.isUpcoming) ? 0.15 : 0))
        let detail = activeCount > 0 ? "\(activeCount) active airspace restrictions" : "\(airspaceNotams.count) upcoming airspace changes"
        return SafetyRiskFactor(id: "airspace", title: "Airspace", score: score, weight: weight, detail: detail, isAvailable: true)
    }

    private func safetyNOTAMFactor() -> SafetyRiskFactor {
        let weight = weightNOTAM
        let active = visibleNOTAMs.filter(\.isActive)
        let upcoming = visibleNOTAMs.filter(\.isUpcoming)
        let score = min(1, Double(active.count) * 0.35 + Double(upcoming.count) * 0.12)
        let detail: String
        if let notamWarningMessage {
            detail = notamWarningMessage
        } else if !active.isEmpty {
            detail = "\(active.count) active NOTAM areas nearby"
        } else if !upcoming.isEmpty {
            detail = "\(upcoming.count) upcoming NOTAM restrictions"
        } else {
            detail = "No active NOTAM conflicts"
        }
        return SafetyRiskFactor(id: "notam", title: "NOTAM", score: score, weight: weight, detail: detail, isAvailable: true)
    }

    private func safetyTerrainFactor() -> SafetyRiskFactor {
        let weight = weightTerrain
        if showPowerInfrastructure, powerWarningMessage != nil {
            return SafetyRiskFactor(id: "terrain", title: "Terrain / Obstacles", score: 0.68, weight: weight, detail: "Obstacle clearance concern from power infrastructure", isAvailable: true)
        }
        return SafetyRiskFactor(id: "terrain", title: "Terrain / Obstacles", score: 0, weight: weight, detail: "DEM unavailable; obstacle checks use powerline data only", isAvailable: false)
    }

    private func safetySignalFactor() -> SafetyRiskFactor {
        let weight = weightSignal
        guard telemetrySignalAvailable else {
            return SafetyRiskFactor(id: "signal", title: "Signal / RF", score: 0, weight: weight, detail: "Telemetry unavailable", isAvailable: false)
        }
        let rssiPenalty = min(1, max(0, (-telemetryRSSI - 60) / 35))
        let linkPenalty = min(1, max(0, (100 - telemetryLinkQualityPercent) / 100))
        let score = min(1, max(rssiPenalty, linkPenalty))
        let detail = "RSSI \(Int(telemetryRSSI)) dBm • Link \(Int(telemetryLinkQualityPercent))%"
        return SafetyRiskFactor(id: "signal", title: "Signal / RF", score: score, weight: weight, detail: detail, isAvailable: true)
    }

    private func safetyWeatherFactor() -> SafetyRiskFactor {
        let weight = weightWeather
        guard let weatherCondition else {
            return SafetyRiskFactor(id: "weather", title: "Weather", score: 0, weight: weight, detail: "Weather conditions unavailable", isAvailable: false)
        }
        let rainScore = min(1, (weatherCondition.precipitationMillimeters ?? 0) / 2)
        let visibilityScore = weatherCondition.visibilityKilometers.map { min(1, max(0, (6 - $0) / 6)) } ?? 0
        let cloudScore = weatherCondition.cloudCoverPercent.map { min(1, $0 / 100) * 0.25 } ?? 0
        let score = min(1, max(rainScore, visibilityScore, cloudScore))
        let detail = weatherWarningMessage ?? weatherCondition.trendSummary
        return SafetyRiskFactor(id: "weather", title: "Weather", score: score, weight: weight, detail: detail, isAvailable: true)
    }

    private func terrainAdvisoryStatus() -> String {
        if let powerWarningMessage {
            return powerWarningMessage
        }
        if configuration(for: .terrainElevation).isSupported {
            return "Terrain elevation monitoring active"
        }
        return "Terrain DEM unavailable. Obstacle awareness uses powerline data only."
    }

    private func signalAdvisoryStatus() -> String {
        guard telemetrySignalAvailable else { return "Signal telemetry unavailable" }
        if telemetryRSSI < -85 || telemetryLinkQualityPercent < 45 {
            return "Weak signal advisory"
        }
        return "Signal metrics within nominal range"
    }

    private func rthAdvisoryStatus(safeRadiusMeters: Double) -> String {
        if projectedFlightDistanceMeters > safeRadiusMeters {
            return "Projected route exceeds estimated safe return radius"
        }
        if let powerWarningMessage, projectedFlightPathEnabled {
            return "RTH path may require higher altitude: \(powerWarningMessage)"
        }
        if projectedFlightPathEnabled && rthAltitudeFeet < droneAltitudeFeet + terrainSafetyMarginFeet {
            return "RTH altitude may be low for current drone altitude"
        }
        return "RTH envelope appears acceptable"
    }

    private func geofenceAdvisoryStatus() -> String {
        guard geofenceEnabled else { return "Geofence advisory off" }
        if projectedFlightDistanceMeters > geofenceRadiusKilometers * 1_000 {
            return "Planned path exceeds advisory geofence radius"
        }
        return "Within advisory geofence"
    }

    private func lightAdvisoryStatus() -> String {
        guard let coordinate = userCoordinate else { return "Light awareness unavailable" }
        let date = Date()
        let sunPosition = Self.sunPosition(on: date, coordinate: coordinate)
        if sunPosition.elevationDegrees < -6 {
            return "Civil twilight or darker conditions"
        }
        if projectedFlightPathEnabled {
            let glareOffset = abs(Self.angularDifferenceDegrees(projectedFlightBearingDegrees, sunPosition.azimuthDegrees))
            if sunPosition.elevationDegrees > 5, sunPosition.elevationDegrees < 25, glareOffset < 30 {
                return "Sun glare likely in planned flight direction"
            }
        }
        if let sunrise = Self.sunEvent(on: date, coordinate: coordinate, isSunrise: true),
           sunrise.timeIntervalSince(date) < 1_800, sunrise > date {
            return "Low light improving soon after sunrise"
        }
        if let sunset = Self.sunEvent(on: date, coordinate: coordinate, isSunrise: false),
           sunset.timeIntervalSince(date) < 3_600, sunset > date {
            return "Low light conditions approaching near sunset"
        }
        return "Daylight conditions acceptable"
    }

    private func estimatedSafeFlightRadiusMeters() -> Double {
        let batteryFactor = telemetryBatteryAvailable ? max(0.15, telemetryBatteryPercent / 100) : 0.55
        let windPenalty = windEstimate.map { min(0.45, $0.speedKilometersPerHour / 100) } ?? 0.18
        let signalPenalty = telemetrySignalAvailable ? min(0.35, max(0, (-telemetryRSSI - 60) / 80)) : 0.1
        return max(350, 2_600 * batteryFactor * (1 - windPenalty) * (1 - signalPenalty))
    }

    private func preflightChecklist(
        windFactor: SafetyRiskFactor,
        trafficFactor: SafetyRiskFactor,
        notamFactor: SafetyRiskFactor,
        signalFactor: SafetyRiskFactor,
        weatherFactor: SafetyRiskFactor,
        safeRadiusMeters: Double
    ) -> [SafetyChecklistItem] {
        [
            SafetyChecklistItem(id: "wind", title: "Wind within limits", isComplete: !windFactor.isAvailable || windFactor.score < 0.55, detail: windFactor.detail),
            SafetyChecklistItem(id: "traffic", title: "Airspace / traffic manageable", isComplete: trafficFactor.score < 0.65, detail: trafficFactor.detail),
            SafetyChecklistItem(id: "notam", title: "NOTAMs reviewed", isComplete: notamReviewedForChecklist || visibleNOTAMs.isEmpty, detail: notamFactor.detail),
            SafetyChecklistItem(id: "signal", title: "Signal OK", isComplete: !telemetrySignalAvailable || signalFactor.score < 0.55, detail: signalFactor.detail),
            SafetyChecklistItem(id: "battery", title: "Battery sufficient", isComplete: !telemetryBatteryAvailable || telemetryBatteryPercent >= 35, detail: telemetryBatteryAvailable ? "\(Int(telemetryBatteryPercent))% remaining" : "Battery telemetry unavailable"),
            SafetyChecklistItem(id: "range", title: "Within safe return range", isComplete: projectedFlightDistanceMeters <= safeRadiusMeters, detail: "\(Int(projectedFlightDistanceMeters)) m planned / \(Int(safeRadiusMeters)) m safe")
        ]
    }

    private func prioritizedSafetyAlerts(
        terrainStatus: String,
        signalStatus: String,
        rthStatus: String,
        lightStatus: String,
        geofenceStatus: String
    ) -> [String] {
        var alerts: [String] = []
        if let primaryAlertMessage { alerts.append(primaryAlertMessage) }
        if let notamWarningMessage { alerts.append(notamWarningMessage) }
        if let powerWarningMessage { alerts.append(powerWarningMessage) }
        if let weatherWarningMessage { alerts.append(weatherWarningMessage) }
        if terrainStatus.contains("concern") || terrainStatus.contains("warning") { alerts.append(terrainStatus) }
        if signalStatus.contains("Weak") { alerts.append(signalStatus) }
        if rthStatus.contains("exceeds") || rthStatus.contains("require") { alerts.append(rthStatus) }
        if lightStatus.contains("glare") || lightStatus.contains("twilight") { alerts.append(lightStatus) }
        if geofenceStatus.contains("exceeds") { alerts.append(geofenceStatus) }
        return Array(alerts.prefix(5))
    }

    private func detectSafetyChanges(nextBand: SafetyRiskBand) -> [String] {
        var changes: [String] = []
        let currentAircraftIDs = Set(alertingAircraft.map(\.id))
        let newAircraft = currentAircraftIDs.subtracting(previousSafetyChangeState.alertingAircraftIDs)
        if !newAircraft.isEmpty {
            changes.append("New aircraft entered the alert zone")
        }

        let activeNotamIDs = Set(visibleNOTAMs.filter(\.isActive).map(\.id))
        if !activeNotamIDs.subtracting(previousSafetyChangeState.activeNotamIDs).isEmpty {
            changes.append("A nearby NOTAM became active")
        }

        let currentWind = windEstimate?.speedKilometersPerHour
        if let previousWind = previousSafetyChangeState.windSpeed, let currentWind, currentWind - previousWind >= 8 {
            changes.append("Wind increased materially")
        }

        if nextBand != previousSafetyChangeState.riskBand {
            changes.append("Risk level changed to \(nextBand.label)")
        }

        previousSafetyChangeState = (currentAircraftIDs, activeNotamIDs, currentWind, nextBand)
        return changes
    }

    private func updateHeading(from heading: CLHeading) {
        guard showHeadingDisplay else { return }
        let preferredHeading = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        guard preferredHeading >= 0 else { return }

        let accuracy = heading.headingAccuracy >= 0 ? heading.headingAccuracy : nil
        let smoothed = smoothedHeading(newValue: preferredHeading)
        headingEstimate = DeviceHeading(
            trueHeadingDegrees: smoothed,
            headingAccuracyDegrees: accuracy,
            source: .compass,
            timestamp: .now
        )
        headingStatus = HeadingAvailability.compassActive.statusText
        headingCalibrationMessage = calibrationMessage(forAccuracy: accuracy)
        refreshHeadingAvailability()
        applyCameraOrientationIfNeeded()
        rebuildPresentation()
    }

    private func updateHeadingFromCourseIfNeeded(_ location: CLLocation) {
        guard showHeadingDisplay else { return }
        guard location.speed >= 1.5, location.course >= 0 else { return }

        if let headingEstimate,
           headingEstimate.source == .compass,
           headingEstimate.isReliable,
           Date().timeIntervalSince(headingEstimate.timestamp) < 3
        {
            return
        }

        let smoothed = smoothedHeading(newValue: location.course)
        self.headingEstimate = DeviceHeading(
            trueHeadingDegrees: smoothed,
            headingAccuracyDegrees: nil,
            source: .gpsCourse,
            timestamp: location.timestamp
        )
        headingStatus = HeadingAvailability.gpsHeading.statusText
        headingCalibrationMessage = "Compass quality is low. Move a short distance for GPS course fallback."
        refreshHeadingAvailability()
        applyCameraOrientationIfNeeded()
        rebuildPresentation()
    }

    private func handleHeadingFailure() {
        if let location = deviceLocation {
            updateHeadingFromCourseIfNeeded(location)
        } else {
            headingEstimate = nil
            headingStatus = locationMonitor.headingSupported ? "No heading (map orientation only)" : "No heading (map orientation only)"
            headingCalibrationMessage = "Compass interference detected. Recalibrate and move away from metal surfaces."
            refreshHeadingAvailability()
        }
    }

    private func refreshHeadingAvailability() {
        if !showHeadingDisplay {
            headingAvailability = .hidden
            headingStatus = headingAvailability.statusText
            return
        }
        if let headingEstimate, headingEstimate.source == .compass, headingEstimate.isReliable {
            headingAvailability = .compassActive
            headingStatus = headingAvailability.statusText
            return
        }
        if let headingEstimate, headingEstimate.source == .gpsCourse {
            headingAvailability = .gpsHeading
            headingStatus = headingAvailability.statusText
            return
        }
        if !locationMonitor.headingSupported {
            headingAvailability = .mapAligned
            headingStatus = headingAvailability.statusText
            return
        }
        if let location = deviceLocation, location.speed < 1.5 {
            headingAvailability = .mapAligned
            headingStatus = headingAvailability.statusText
            if mapOrientationMode == .headingUp {
                mapOrientationMode = .northUp
            }
            return
        }
        headingAvailability = .waitingForSensor
        headingStatus = headingAvailability.statusText
    }

    private func calibrationMessage(forAccuracy accuracy: Double?) -> String? {
        guard let accuracy else { return nil }
        if accuracy > 25 {
            return "Compass accuracy is low. Calibrate by moving the device in a figure-eight."
        }
        return nil
    }

    private func smoothedHeading(newValue: Double) -> Double {
        guard let current = headingEstimate?.trueHeadingDegrees else { return Self.normalizedDegrees(newValue) }
        let delta = ((newValue - current + 540).truncatingRemainder(dividingBy: 360)) - 180
        let next = current + delta * max(0.05, min(headingSmoothingFactor, 0.95))
        return Self.normalizedDegrees(next)
    }

    private func applyCameraOrientationIfNeeded(region: MKCoordinateRegion? = nil) {
        guard let coordinate = userCoordinate else { return }
        let activeRegion = region ?? visibleRegion ?? Self.region(centeredOn: coordinate, radiusMeters: max(alertRadiusMeters * 1.6, 6_000))
        let distance = Self.cameraDistance(for: activeRegion)
        let heading = mapOrientationMode == .headingUp && hasReliableHeading ? effectiveReferenceHeadingDegrees : 0
        cameraPosition = .camera(
            MapCamera(
                centerCoordinate: coordinate,
                distance: distance,
                heading: heading,
                pitch: mapPresentation == .terrain || mapPresentation == .topographic ? 40 : 0
            )
        )
    }

    private func playAlertIfNeeded(for aircraft: [AircraftPresentation]) {
        guard audioAlertsEnabled, !isPreview else { return }
        guard let alertCandidate = aircraft.prefix(3).max(by: { $0.urgencyScore < $1.urgencyScore }) else {
            trafficAlertStatus = "No traffic inside the configured alert zone"
            return
        }

        let now = Date()
        if let recent = recentAlertTimes[alertCandidate.id], now.timeIntervalSince(recent) < trafficAlertSensitivity.cooldownSeconds {
            trafficAlertStatus = "Traffic alert cooldown active for \(alertCandidate.displayName)"
            return
        }
        recentAlertTimes[alertCandidate.id] = now

        let mode = effectiveTrafficAlertMode
        if mode == .tone || mode == .toneAndVoice {
            playTrafficAlertTone(for: alertCandidate)
        }
        if mode == .voice || mode == .toneAndVoice {
            speakTrafficAlert(for: alertCandidate)
        }
        trafficAlertStatus = trafficAlertSummary(for: alertCandidate)
    }

    private func playTrafficAlertTone(for aircraft: AircraftPresentation) {
        let selectedSound = aircraft.urgencyScore >= 0.8 ? TrafficAlertSound.submarine : trafficAlertSound
        if selectedSound == .custom,
           let sound = loadCustomTrafficAlertSound()
        {
            sound.volume = Float(trafficAlertVolume)
            sound.play()
            return
        }

        if let soundName = selectedSound.soundName, let sound = NSSound(named: soundName) {
            sound.volume = Float(trafficAlertVolume)
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func loadCustomTrafficAlertSound() -> NSSound? {
        let trimmedPath = customTrafficAlertSoundPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }
        return NSSound(contentsOf: URL(fileURLWithPath: trimmedPath), byReference: true)
    }

    private func speakTrafficAlert(for aircraft: AircraftPresentation) {
        let message = trafficAlertVoiceMessage(for: aircraft)
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = 0.5
        utterance.volume = Float(trafficAlertVolume)
        speechSynthesizer.speak(utterance)
    }

    private func trafficAlertVoiceMessage(for aircraft: AircraftPresentation) -> String {
        let distance = max(1, Int(aircraft.distanceKilometers.rounded()))
        if !hasReliableHeading {
            if aircraft.urgencyScore >= 0.8 {
                return "Low aircraft approaching. Within \(distance) kilometers."
            }
            if aircraft.isApproaching {
                return "Aircraft nearby. Within \(distance) kilometers."
            }
            return "Aircraft within \(distance) kilometers."
        }

        let direction = aircraft.relativeBearingDegrees.map(Self.voiceDirectionDescription(for:)) ?? "nearby"
        if aircraft.urgencyScore >= 0.8 {
            return "Low aircraft approaching from \(direction). Within \(distance) kilometers."
        }
        if aircraft.isApproaching {
            return "Aircraft nearby from \(direction). Within \(distance) kilometers."
        }
        return "Aircraft within \(distance) kilometers."
    }

    private func trafficAlertSummary(for aircraft: AircraftPresentation) -> String {
        let urgency: String
        switch aircraft.urgencyScore {
        case 0.8...:
            urgency = "High"
        case 0.55...:
            urgency = "Medium"
        default:
            urgency = "Low"
        }
        return "\(urgency) traffic alert: \(aircraft.displayName) at \(Int(aircraft.relativeAltitudeFeet)) ft AGL and \(Self.formatted(aircraft.distanceKilometers, decimals: 1)) km"
    }

    private static func trafficUrgencyScore(distanceMeters: Double, relativeAltitudeFeet: Double, isApproaching: Bool, isDescending: Bool, isAhead: Bool) -> Double {
        let distanceFactor = max(0, 1 - min(distanceMeters, 4_000) / 4_000)
        let altitudeFactor = max(0, 1 - min(relativeAltitudeFeet, 2_000) / 2_000)
        let approachFactor = isApproaching ? 0.18 : 0
        let descentFactor = isDescending ? 0.12 : 0
        let headingFactor = isAhead ? 0.1 : 0
        return min(1, distanceFactor * 0.45 + altitudeFactor * 0.25 + approachFactor + descentFactor + headingFactor)
    }

    private static func voiceDirectionDescription(for relativeBearing: Double) -> String {
        switch Int(relativeBearing.rounded()) {
        case 0 ..< 20, 340 ... 360:
            "ahead"
        case 20 ..< 70:
            "front right"
        case 70 ..< 120:
            "right"
        case 120 ..< 160:
            "rear right"
        case 160 ..< 200:
            "behind"
        case 200 ..< 250:
            "rear left"
        case 250 ..< 300:
            "left"
        default:
            "front left"
        }
    }

    private func merge(local: [AircraftContact], network: [AircraftContact]) -> [AircraftContact] {
        var merged = Dictionary(uniqueKeysWithValues: network.map { ($0.id, $0) })
        for contact in local {
            merged[contact.id] = contact
        }
        return Array(merged.values)
    }

    private func seedPreviewState() {
        let sampleLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.6189, longitude: -122.3750),
            altitude: 15,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: .now
        )
        deviceLocation = sampleLocation
        applyReferenceLocation(sampleLocation)
        headingEstimate = DeviceHeading(trueHeadingDegrees: 312, headingAccuracyDegrees: 8, source: .compass, timestamp: .now)
        headingStatus = "Preview heading from compass"
        windEstimate = WindEstimate(speedKilometersPerHour: 19, gustKilometersPerHour: 28, directionDegrees: 310, fetchedAt: .now)
        windStatus = "Estimated wind from preview weather data"
        weatherCondition = AtmosphericCondition(
            temperatureCelsius: 22,
            pressureHectopascals: 1014,
            humidityPercent: 48,
            precipitationMillimeters: 0,
            precipitationProbabilityPercent: 10,
            cloudCoverPercent: 22,
            visibilityKilometers: 10,
            weatherCode: 1,
            fetchedAt: .now,
            trendSummary: "Stable conditions over the next few hours"
        )
        weatherStatus = "Estimated atmospheric conditions from preview weather data"
        showPowerInfrastructure = true
        powerStatus = "Preview power infrastructure"
        powerLines = [
            PowerLineFeature(
                id: "preview-line-1",
                coordinates: [
                    CLLocationCoordinate2D(latitude: 37.621, longitude: -122.385),
                    CLLocationCoordinate2D(latitude: 37.624, longitude: -122.365)
                ],
                category: .transmission,
                source: "Preview fallback"
            )
        ]
        powerStructures = [
            PowerStructure(id: "preview-tower-1", coordinate: CLLocationCoordinate2D(latitude: 37.6222, longitude: -122.378), kind: "tower", source: "Preview fallback")
        ]
        manualLatitude = "37.6189"
        manualLongitude = "-122.3750"
        manualCoordinateSummary = "Using 37.6189, -122.3750"
        showFireLayer = true
        rawFireDetections = [
            FireDetection(id: "preview-fire-1", coordinate: CLLocationCoordinate2D(latitude: 37.626, longitude: -122.362), detectedAt: .now.addingTimeInterval(-2_400), source: "VIIRS", confidence: .high, brightness: 356, frp: 18),
            FireDetection(id: "preview-fire-2", coordinate: CLLocationCoordinate2D(latitude: 37.629, longitude: -122.368), detectedAt: .now.addingTimeInterval(-7_200), source: "MODIS", confidence: .medium, brightness: 328, frp: 8)
        ]
        fireStatus = "Preview FIRMS hotspot layer"
        filterFireDetections()
        showNotamLayer = true
        notamRawInput = """
        H1234/26 NOTAMN
        Q) YMMM/QRRCA/IV/BO/W/000/015/3456S13836E005
        A) YPAD
        B) 202603300100
        C) 202603300500
        E) TEMPORARY RESTRICTED AREA DUE FIRE FIGHTING ACFT OPS WI 5NM RADIUS OF PSN 3456S13836E SFC-1500FT
        """
        parsedNOTAMs = NOTAMParser.parse(rawText: notamRawInput)
        notamStatus = "Preview NOTAM parser"
        filterNOTAMs()

        localSnapshot = FeedSnapshot(
            contacts: [
                AircraftContact(icao: "a1b2c3", callsign: "N214DP", coordinate: CLLocationCoordinate2D(latitude: 37.611, longitude: -122.366), heading: 45, speedKnots: 102, altitudeFeetMSL: 980, source: .sdr, lastSeen: .now),
                AircraftContact(icao: "d4e5f6", callsign: "UAL842", coordinate: CLLocationCoordinate2D(latitude: 37.632, longitude: -122.401), heading: 180, speedKnots: 168, altitudeFeetMSL: 2_700, source: .sdr, lastSeen: .now)
            ],
            fetchedAt: .now,
            detail: "Preview local decoder"
        )

        networkSnapshot = FeedSnapshot(
            contacts: [
                AircraftContact(icao: "112233", callsign: "SWA18", coordinate: CLLocationCoordinate2D(latitude: 37.644, longitude: -122.352), heading: 312, speedKnots: 140, altitudeFeetMSL: 1_350, source: .network, lastSeen: .now)
            ],
            fetchedAt: .now,
            detail: "Preview network feed"
        )

        rebuildPresentation()
    }

    private static func region(centeredOn coordinate: CLLocationCoordinate2D, radiusMeters: CLLocationDistance) -> MKCoordinateRegion {
        let latitudeDelta = max(0.04, radiusMeters / 111_000 * 2.4)
        let longitudeDelta = max(0.04, radiusMeters / max(20_000, cos(coordinate.latitude * .pi / 180) * 111_000) * 2.4)
        return MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private static func cameraDistance(for region: MKCoordinateRegion) -> Double {
        let dominantDelta = max(region.span.latitudeDelta, region.span.longitudeDelta)
        return max(1_200, dominantDelta * 111_000 * 1.25)
    }

    nonisolated private static func formatted(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }

    nonisolated private static func normalizedDegrees(_ value: Double) -> Double {
        let normalized = value.truncatingRemainder(dividingBy: 360)
        return normalized >= 0 ? normalized : normalized + 360
    }

    nonisolated private static func normalizedAngle(_ value: Double) -> Double {
        normalizedDegrees(value)
    }

    nonisolated private static func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let startLatitude = start.latitude * .pi / 180
        let startLongitude = start.longitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let endLongitude = end.longitude * .pi / 180
        let y = sin(endLongitude - startLongitude) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude) - sin(startLatitude) * cos(endLatitude) * cos(endLongitude - startLongitude)
        return normalizedDegrees(atan2(y, x) * 180 / .pi)
    }

    nonisolated private static func angularDifferenceDegrees(_ lhs: Double, _ rhs: Double) -> Double {
        abs(((lhs - rhs + 540).truncatingRemainder(dividingBy: 360)) - 180)
    }

    private static func sunPosition(on date: Date, coordinate: CLLocationCoordinate2D) -> (azimuthDegrees: Double, elevationDegrees: Double) {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let components = calendar.dateComponents(in: .current, from: date)
        let hour = Double(components.hour ?? 12)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        let gamma = 2 * Double.pi / 365 * (Double(dayOfYear) - 1 + ((hour - 12) / 24))
        let declination = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.00148 * sin(3 * gamma)
        let equationOfTime = 229.18 * (
            0.000075
                + 0.001868 * cos(gamma)
                - 0.032077 * sin(gamma)
                - 0.014615 * cos(2 * gamma)
                - 0.040849 * sin(2 * gamma)
        )
        let timezoneOffsetMinutes = Double(TimeZone.current.secondsFromGMT(for: date)) / 60
        let trueSolarMinutes = hour * 60 + minute + second / 60 + equationOfTime + 4 * coordinate.longitude - timezoneOffsetMinutes
        let hourAngle = (trueSolarMinutes / 4 - 180) * Double.pi / 180
        let latitude = coordinate.latitude * Double.pi / 180
        let zenith = acos(
            sin(latitude) * sin(declination) +
                cos(latitude) * cos(declination) * cos(hourAngle)
        )
        let elevation = 90 - zenith * 180 / .pi
        let azimuth = atan2(
            sin(hourAngle),
            cos(hourAngle) * sin(latitude) - tan(declination) * cos(latitude)
        ) * 180 / .pi + 180
        return (normalizedDegrees(azimuth), elevation)
    }

    private static func sunEvent(on date: Date, coordinate: CLLocationCoordinate2D, isSunrise: Bool) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let longitudeHour = coordinate.longitude / 15
        let approximateTime = isSunrise ? dayOfYear + ((6 - longitudeHour) / 24) : dayOfYear + ((18 - longitudeHour) / 24)
        let meanAnomaly = 0.9856 * approximateTime - 3.289
        var trueLongitude = meanAnomaly + 1.916 * sin(meanAnomaly * .pi / 180) + 0.020 * sin(2 * meanAnomaly * .pi / 180) + 282.634
        trueLongitude = normalizedDegrees(trueLongitude)

        var rightAscension = atan(0.91764 * tan(trueLongitude * .pi / 180)) * 180 / .pi
        rightAscension = normalizedDegrees(rightAscension)
        let longitudeQuadrant = floor(trueLongitude / 90) * 90
        let rightAscensionQuadrant = floor(rightAscension / 90) * 90
        rightAscension = (rightAscension + longitudeQuadrant - rightAscensionQuadrant) / 15

        let sinDeclination = 0.39782 * sin(trueLongitude * .pi / 180)
        let cosDeclination = cos(asin(sinDeclination))
        let latitude = coordinate.latitude * .pi / 180
        let zenith = 96.0 * .pi / 180
        let cosLocalHourAngle = (cos(zenith) - sinDeclination * sin(latitude)) / (cosDeclination * cos(latitude))
        guard (-1 ... 1).contains(cosLocalHourAngle) else { return nil }

        let localHourAngle = (isSunrise ? (360 - acos(cosLocalHourAngle) * 180 / .pi) : (acos(cosLocalHourAngle) * 180 / .pi)) / 15
        let localMeanTime = localHourAngle + rightAscension - 0.06571 * approximateTime - 6.622
        let universalTime = normalizedDegrees((localMeanTime - longitudeHour) * 15) / 15
        let startOfDay = calendar.startOfDay(for: date)
        return startOfDay.addingTimeInterval(universalTime * 3_600)
    }

    private var referenceLocation: CLLocation? {
        switch locationSourcePreference {
        case .deviceGPS:
            deviceLocation
        case .manualCoordinates:
            manualLocation ?? deviceLocation
        }
    }

    private func syncLocationSource() {
        switch locationSourcePreference {
        case .deviceGPS:
            if let deviceLocation {
                applyReferenceLocation(deviceLocation)
            }
        case .manualCoordinates:
            if manualLocation == nil {
                applyManualCoordinates()
            } else if let manualLocation {
                applyReferenceLocation(manualLocation)
            }
        }
    }

    private func refreshAtmosphereNow() {
        guard !isPreview else { return }
        Task { [weak self] in
            guard let self else { return }
            let result = await self.atmosphereProvider.fetchAtmosphere(at: await MainActor.run { self.referenceLocation?.coordinate })
            await MainActor.run {
                self.windEstimate = result?.wind
                self.windStatus = result?.windStatus ?? "Waiting for weather data"
                self.weatherCondition = result?.condition
                self.weatherStatus = result?.weatherStatus ?? "Waiting for atmospheric data"
                self.rebuildWeatherWarnings()
            }
        }
    }

    private func refreshPowerInfrastructure() {
        guard showPowerInfrastructure else { return }
        let region = visibleRegion ?? fallbackPowerRegion
        guard let region else {
            powerStatus = "Waiting for map location before loading power infrastructure"
            return
        }

        powerFetchTask?.cancel()
        powerFetchTask = Task { [weak self] in
            guard let self else { return }
            let snapshot = await self.powerProvider.fetch(in: region)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.powerLines = snapshot.lines
                self.powerStructures = snapshot.structures
                self.powerStatus = snapshot.status
                self.rebuildPowerWarnings()
            }
        }
    }

    private func refreshFireDetections() {
        guard showFireLayer else { return }
        let region = visibleRegion ?? fallbackPowerRegion
        guard let region else {
            fireStatus = "Waiting for map location before loading FIRMS detections"
            return
        }

        fireFetchTask?.cancel()
        fireFetchTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.fireProvider.fetch(in: region)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.rawFireDetections = result.detections
                self.fireStatus = result.status
                self.filterFireDetections()
            }
        }
    }

    private var fallbackPowerRegion: MKCoordinateRegion? {
        guard let coordinate = userCoordinate else { return nil }
        return Self.region(centeredOn: coordinate, radiusMeters: 2_500)
    }

    private func rebuildPowerWarnings() {
        guard showPowerInfrastructure, let userCoordinate else {
            powerWarningMessage = nil
            return
        }

        let userConflict = powerLines.contains { Self.coordinate(userCoordinate, isWithin: powerBufferMeters, of: $0.coordinates) }
        let pathConflict = projectedFlightPathCoordinates.count == 2 && powerLines.contains {
            Self.path(projectedFlightPathCoordinates, intersectsBuffer: powerBufferMeters, around: $0.coordinates)
        }

        if userConflict || pathConflict {
            if userConflict && pathConflict {
                powerWarningMessage = "Powerline buffer intersects your position and projected path."
            } else if userConflict {
                powerWarningMessage = "You are inside the configured powerline buffer."
            } else {
                powerWarningMessage = "Projected flight path intersects the configured powerline buffer."
            }

            playPowerAlertIfNeeded()
        } else {
            powerWarningMessage = nil
        }
    }

    private func filterFireDetections() {
        let cutoff = Date().addingTimeInterval(-fireRecencyFilter.maximumAge)
        fireDetections = rawFireDetections
            .filter { $0.detectedAt >= cutoff && $0.confidence >= minimumFireConfidence }
            .sorted { $0.detectedAt > $1.detectedAt }
        rebuildFireWarnings()
    }

    private func rebuildFireWarnings() {
        guard showFireLayer, let referenceLocation else {
            fireWarningMessage = nil
            return
        }

        let nearby = fireDetections.filter {
            CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude).distance(from: referenceLocation) <= fireAlertRadiusKilometers * 1_000
        }

        if nearby.isEmpty {
            fireWarningMessage = nil
            return
        }

        if nearby.count >= 3 {
            fireWarningMessage = "Multiple nearby FIRMS detections suggest an active fire zone."
        } else {
            fireWarningMessage = "Satellite fire detection is within \(Int(fireAlertRadiusKilometers)) km of your position."
        }

        playFireAlertIfNeeded()
    }

    private func playFireAlertIfNeeded() {
        guard fireAudioAlertsEnabled, !isPreview else { return }
        let now = Date()
        if let recentFireAlertAt, now.timeIntervalSince(recentFireAlertAt) < 30 {
            return
        }
        recentFireAlertAt = now
        NSSound.beep()
    }

    private func rebuildWeatherWarnings() {
        guard showWeatherPanel else {
            weatherWarningMessage = nil
            return
        }

        var warnings: [String] = []
        if let wind = windEstimate, wind.speedKilometersPerHour >= weatherHighWindThresholdKilometersPerHour {
            warnings.append("High wind estimated")
        }
        if let precipitation = weatherCondition?.precipitationMillimeters, precipitation >= weatherRainThresholdMillimeters {
            warnings.append("Rain detected")
        } else if let probability = weatherCondition?.precipitationProbabilityPercent, probability >= 50 {
            warnings.append("Rain possible soon")
        }
        if let visibility = weatherCondition?.visibilityKilometers, visibility <= weatherLowVisibilityThresholdKilometers {
            warnings.append("Low visibility")
        }

        weatherWarningMessage = warnings.isEmpty ? nil : warnings.joined(separator: " • ")
        if weatherWarningMessage != nil {
            playWeatherAlertIfNeeded()
        }
    }

    private func playWeatherAlertIfNeeded() {
        guard weatherAudioAlertsEnabled, !isPreview else { return }
        let now = Date()
        if let recentWeatherAlertAt, now.timeIntervalSince(recentWeatherAlertAt) < 30 {
            return
        }
        recentWeatherAlertAt = now
        NSSound.beep()
    }

    private func refreshAutomatedNOTAMs() {
        guard showNotamLayer else { return }
        Task { [weak self] in
            guard let self else { return }
            let location = await MainActor.run { self.referenceLocation }
            let result = await self.notamProvider.fetchBriefingText(around: location)
            await MainActor.run {
                if let result {
                    if !result.rawText.isEmpty {
                        self.notamRawInput = result.rawText
                        self.parsedNOTAMs = NOTAMParser.parse(rawText: result.rawText)
                    }
                    self.notamStatus = result.status
                }
                self.filterNOTAMs()
            }
        }
    }

    private func filterNOTAMs() {
        let source = parsedNOTAMs.filter { notam in
            if let until = notam.validUntil, until < Date() {
                return false
            }
            return true
        }

        switch notamDisplayMode {
        case .showAll:
            visibleNOTAMs = source
        case .relevantOnly:
            guard let referenceLocation else {
                visibleNOTAMs = source
                rebuildNOTAMWarnings()
                return
            }
            visibleNOTAMs = source.filter { notam in
                let proximityOkay = Self.notam(notam, isNear: referenceLocation.coordinate, radiusMeters: notamAlertRadiusKilometers * 1_000)
                let altitudeOkay = notam.altitudeBand.lowerFeet == nil || (notam.altitudeBand.lowerFeet ?? 0) <= notamAltitudeThresholdFeet
                return proximityOkay || altitudeOkay
            }
        }

        rebuildNOTAMWarnings()
    }

    private func rebuildNOTAMWarnings() {
        guard showNotamLayer, let referenceCoordinate = userCoordinate else {
            notamWarningMessage = nil
            return
        }

        let activeConflicts = visibleNOTAMs.filter { notam in
            guard notam.isActive else { return false }
            let areaConflict = Self.notamContainsCoordinate(notam, coordinate: referenceCoordinate)
            let pathConflict = projectedFlightPathCoordinates.count == 2 && Self.notamIntersectsPath(notam, path: projectedFlightPathCoordinates)
            let altitudeConflict = notam.altitudeBand.intersects(plannedAltitudeFeet: notamPlannedAltitudeFeet)
            return (areaConflict || pathConflict) && altitudeConflict
        }

        if let first = activeConflicts.first {
            if activeConflicts.count > 1 {
                notamWarningMessage = "Multiple active NOTAM restrictions affect your position or planned path."
            } else {
                notamWarningMessage = "\(first.kind.label) NOTAM conflicts with current position or planned flight."
            }
            playNOTAMAlertIfNeeded()
            return
        }

        if let upcoming = visibleNOTAMs.first(where: \.isUpcoming) {
            notamWarningMessage = "\(upcoming.kind.label) NOTAM becomes active soon."
        } else {
            notamWarningMessage = nil
        }
    }

    private func playNOTAMAlertIfNeeded() {
        guard notamAudioAlertsEnabled, !isPreview else { return }
        let now = Date()
        if let recentNotamAlertAt, now.timeIntervalSince(recentNotamAlertAt) < 30 {
            return
        }
        recentNotamAlertAt = now
        NSSound.beep()
    }

    nonisolated private static func notam(_ notam: StructuredNOTAM, isNear coordinate: CLLocationCoordinate2D, radiusMeters: Double) -> Bool {
        guard let geometry = notam.geometry else { return false }
        switch geometry {
        case let .circle(center, notamRadius):
            let distance = CLLocation(latitude: center.latitude, longitude: center.longitude).distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            return distance <= max(radiusMeters, notamRadius + radiusMeters)
        case let .polygon(coordinates):
            return Self.coordinate(coordinate, isWithin: radiusMeters, of: coordinates)
        }
    }

    nonisolated private static func notamContainsCoordinate(_ notam: StructuredNOTAM, coordinate: CLLocationCoordinate2D) -> Bool {
        guard let geometry = notam.geometry else { return false }
        switch geometry {
        case let .circle(center, radiusMeters):
            let distance = CLLocation(latitude: center.latitude, longitude: center.longitude).distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            return distance <= radiusMeters
        case let .polygon(coordinates):
            return pointInPolygon(coordinate, polygon: coordinates)
        }
    }

    nonisolated private static func notamIntersectsPath(_ notam: StructuredNOTAM, path: [CLLocationCoordinate2D]) -> Bool {
        guard let geometry = notam.geometry, path.count >= 2 else { return false }
        switch geometry {
        case let .circle(center, radiusMeters):
            return Self.coordinate(center, isWithin: radiusMeters, of: path)
        case let .polygon(coordinates):
            return Self.path(path, intersectsBuffer: 0, around: coordinates)
        }
    }

    nonisolated private static func pointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var contains = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude
            let intersects = ((yi > point.latitude) != (yj > point.latitude)) &&
                (point.longitude < (xj - xi) * (point.latitude - yi) / ((yj - yi) == 0 ? 0.0000001 : (yj - yi)) + xi)
            if intersects { contains.toggle() }
            j = i
        }
        return contains
    }

    private func playPowerAlertIfNeeded() {
        guard powerAudioAlertsEnabled, !isPreview else { return }
        let now = Date()
        if let recentPowerAlertAt, now.timeIntervalSince(recentPowerAlertAt) < 20 {
            return
        }
        recentPowerAlertAt = now
        NSSound.beep()
    }

    nonisolated private static func destinationCoordinate(from start: CLLocationCoordinate2D, distanceMeters: Double, bearingDegrees: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6_371_000.0
        let bearing = bearingDegrees * .pi / 180
        let latitude1 = start.latitude * .pi / 180
        let longitude1 = start.longitude * .pi / 180
        let angularDistance = distanceMeters / earthRadius

        let latitude2 = asin(sin(latitude1) * cos(angularDistance) + cos(latitude1) * sin(angularDistance) * cos(bearing))
        let longitude2 = longitude1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(latitude1),
            cos(angularDistance) - sin(latitude1) * sin(latitude2)
        )

        return CLLocationCoordinate2D(latitude: latitude2 * 180 / .pi, longitude: longitude2 * 180 / .pi)
    }

    nonisolated private static func coordinate(_ point: CLLocationCoordinate2D, isWithin bufferMeters: Double, of polyline: [CLLocationCoordinate2D]) -> Bool {
        guard polyline.count >= 2 else { return false }
        let local = polyline.map { localPoint(for: $0, reference: point) }
        let target = SIMD2<Double>(0, 0)

        for index in 0 ..< (local.count - 1) {
            if distance(from: target, toSegment: local[index], local[index + 1]) <= bufferMeters {
                return true
            }
        }

        return false
    }

    nonisolated private static func path(_ path: [CLLocationCoordinate2D], intersectsBuffer bufferMeters: Double, around polyline: [CLLocationCoordinate2D]) -> Bool {
        guard path.count >= 2, polyline.count >= 2 else { return false }
        let reference = path[0]
        let flight = path.map { localPoint(for: $0, reference: reference) }
        let line = polyline.map { localPoint(for: $0, reference: reference) }

        for pathIndex in 0 ..< (flight.count - 1) {
            for lineIndex in 0 ..< (line.count - 1) {
                if segmentDistance(flight[pathIndex], flight[pathIndex + 1], line[lineIndex], line[lineIndex + 1]) <= bufferMeters {
                    return true
                }
            }
        }

        return false
    }

    nonisolated private static func localPoint(for coordinate: CLLocationCoordinate2D, reference: CLLocationCoordinate2D) -> SIMD2<Double> {
        let metersPerDegreeLatitude = 111_132.0
        let metersPerDegreeLongitude = max(1, cos(reference.latitude * .pi / 180) * 111_320.0)
        return SIMD2<Double>(
            (coordinate.longitude - reference.longitude) * metersPerDegreeLongitude,
            (coordinate.latitude - reference.latitude) * metersPerDegreeLatitude
        )
    }

    nonisolated private static func distance(from point: SIMD2<Double>, toSegment a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let ab = b - a
        let lengthSquared = simd_length_squared(ab)
        guard lengthSquared > 0 else { return simd_distance(point, a) }
        let t = max(0, min(1, simd_dot(point - a, ab) / lengthSquared))
        let projection = a + ab * t
        return simd_distance(point, projection)
    }

    nonisolated private static func segmentDistance(_ a1: SIMD2<Double>, _ a2: SIMD2<Double>, _ b1: SIMD2<Double>, _ b2: SIMD2<Double>) -> Double {
        min(
            distance(from: a1, toSegment: b1, b2),
            distance(from: a2, toSegment: b1, b2),
            distance(from: b1, toSegment: a1, a2),
            distance(from: b2, toSegment: a1, a2)
        )
    }
}

final class LocationMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var currentLocation: CLLocation?

    var onLocationUpdate: ((CLLocation) -> Void)?
    var onHeadingUpdate: ((CLHeading) -> Void)?
    var onHeadingFailure: (() -> Void)?

    private let manager = CLLocationManager()
    let headingSupported = CLLocationManager.headingAvailable()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.headingFilter = kCLHeadingFilterNone
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        currentLocation = latest
        onLocationUpdate?(latest)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        onHeadingUpdate?(newHeading)
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        #if os(macOS)
        guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorized else { return }
        #else
        guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else { return }
        #endif
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        if let error = error as? CLError, error.code == .headingFailure {
            onHeadingFailure?()
        }
    }
}

actor LocalSDRProvider {
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 0.9
        return URLSession(configuration: configuration)
    }()

    private let endpoints = [
        URL(string: "http://127.0.0.1:8080/data/aircraft.json"),
        URL(string: "http://127.0.0.1:8754/data/aircraft.json"),
        URL(string: "http://127.0.0.1/tar1090/data/aircraft.json")
    ].compactMap { $0 }

    func fetch() async -> FeedSnapshot? {
        for endpoint in endpoints {
            do {
                let (data, response) = try await session.data(from: endpoint)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    continue
                }

                let contacts = try parseContacts(from: data)
                return FeedSnapshot(contacts: contacts, fetchedAt: .now, detail: "Local decoder \(endpoint.host() ?? "localhost") with \(contacts.count) targets")
            } catch {
                continue
            }
        }

        return FeedSnapshot(contacts: [], fetchedAt: .now, detail: "No SkyAware/readsb endpoint responding on localhost")
    }

    nonisolated private func parseContacts(from data: Data) throws -> [AircraftContact] {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let aircraft = root["aircraft"] as? [[String: Any]]
        else {
            return []
        }

        return aircraft.compactMap { entry in
            guard
                let icao = JSONField.string(entry["hex"])?.lowercased(),
                let latitude = JSONField.double(entry["lat"]),
                let longitude = JSONField.double(entry["lon"])
            else {
                return nil
            }

            let heading = JSONField.double(entry["track"]) ?? 0
            let speedKnots = JSONField.double(entry["gs"]) ?? 0
            let altitudeFeet = JSONField.double(entry["alt_geom"]) ?? JSONField.double(entry["alt_baro"]) ?? JSONField.double(entry["altitude"]) ?? 0
            let seenSeconds = JSONField.double(entry["seen"]) ?? 0
            guard seenSeconds < 15 else { return nil }

            return AircraftContact(
                icao: icao,
                callsign: JSONField.string(entry["flight"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                heading: heading,
                speedKnots: speedKnots,
                altitudeFeetMSL: altitudeFeet,
                source: .sdr,
                lastSeen: Date().addingTimeInterval(-seenSeconds)
            )
        }
    }
}

actor OpenSkyNetworkProvider {
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        return URLSession(configuration: configuration)
    }()

    func fetch(around location: CLLocation?, radiusMeters: CLLocationDistance) async -> FeedSnapshot? {
        guard let location, let url = url(for: location.coordinate, radiusMeters: radiusMeters) else {
            return FeedSnapshot(contacts: [], fetchedAt: .now, detail: "Waiting for user GPS fix before network polling")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        if
            let username = ProcessInfo.processInfo.environment["OPENSKY_USERNAME"],
            let password = ProcessInfo.processInfo.environment["OPENSKY_PASSWORD"]
        {
            let token = Data("\(username):\(password)".utf8).base64EncodedString()
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return FeedSnapshot(contacts: [], fetchedAt: .now, detail: "Network feed unavailable")
            }

            let contacts = try parseContacts(from: data)
            return FeedSnapshot(contacts: contacts, fetchedAt: .now, detail: "OpenSky fallback with \(contacts.count) targets")
        } catch {
            return FeedSnapshot(contacts: [], fetchedAt: .now, detail: "Network request failed")
        }
    }

    private func url(for coordinate: CLLocationCoordinate2D, radiusMeters: CLLocationDistance) -> URL? {
        let latitudeDelta = radiusMeters / 111_000
        let longitudeScale = max(0.25, cos(coordinate.latitude * .pi / 180))
        let longitudeDelta = radiusMeters / (111_000 * longitudeScale)

        var components = URLComponents(string: "https://opensky-network.org/api/states/all")
        components?.queryItems = [
            URLQueryItem(name: "lamin", value: String(coordinate.latitude - latitudeDelta)),
            URLQueryItem(name: "lomin", value: String(coordinate.longitude - longitudeDelta)),
            URLQueryItem(name: "lamax", value: String(coordinate.latitude + latitudeDelta)),
            URLQueryItem(name: "lomax", value: String(coordinate.longitude + longitudeDelta))
        ]
        return components?.url
    }

    nonisolated private func parseContacts(from data: Data) throws -> [AircraftContact] {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let states = root["states"] as? [[Any]]
        else {
            return []
        }

        return states.compactMap { state in
            guard state.count > 13 else { return nil }
            guard
                let icao = state[0] as? String,
                let longitude = JSONField.double(state[5]),
                let latitude = JSONField.double(state[6])
            else {
                return nil
            }

            let onGround = state[8] as? Bool ?? false
            guard !onGround else { return nil }

            let altitudeMeters = JSONField.double(state[13]) ?? JSONField.double(state[7]) ?? 0
            let speedMetersPerSecond = JSONField.double(state[9]) ?? 0
            let heading = JSONField.double(state[10]) ?? 0

            return AircraftContact(
                icao: icao.lowercased(),
                callsign: (state[1] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                heading: heading,
                speedKnots: speedMetersPerSecond * 1.94384,
                altitudeFeetMSL: altitudeMeters * 3.28084,
                source: .network,
                lastSeen: .now
            )
        }
    }
}

struct AtmosphericFetchResult {
    let wind: WindEstimate?
    let condition: AtmosphericCondition?
    let windStatus: String
    let weatherStatus: String
}

struct FireFetchResult {
    let detections: [FireDetection]
    let status: String
}

struct NOTAMFetchResult {
    let rawText: String
    let status: String
}

actor AtmosphericWeatherProvider {
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        return URLSession(configuration: configuration)
    }()

    func fetchAtmosphere(at coordinate: CLLocationCoordinate2D?) async -> AtmosphericFetchResult? {
        guard let coordinate, let url = url(for: coordinate) else {
            return AtmosphericFetchResult(wind: nil, condition: nil, windStatus: "Waiting for coordinates before weather polling", weatherStatus: "Waiting for atmospheric data")
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return AtmosphericFetchResult(wind: nil, condition: nil, windStatus: "Weather API unavailable", weatherStatus: "Weather API unavailable")
            }

            let snapshot = try parseSnapshot(from: data)
            return AtmosphericFetchResult(
                wind: snapshot.wind,
                condition: snapshot.condition,
                windStatus: snapshot.wind == nil ? "No current wind data from weather API" : "Estimated wind (weather data)",
                weatherStatus: snapshot.condition == nil ? "No current atmospheric data from weather API" : "Estimated weather (stations/models)"
            )
        } catch {
            return AtmosphericFetchResult(wind: nil, condition: nil, windStatus: "Weather request failed", weatherStatus: "Weather request failed")
        }
    }

    private func url(for coordinate: CLLocationCoordinate2D) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,surface_pressure,precipitation,cloud_cover,visibility,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
            URLQueryItem(name: "hourly", value: "surface_pressure,precipitation_probability"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }

    nonisolated private func parseSnapshot(from data: Data) throws -> (wind: WindEstimate?, condition: AtmosphericCondition?) {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let current = root["current"] as? [String: Any]
        else {
            return (nil, nil)
        }

        let wind: WindEstimate?
        if let speed = JSONField.double(current["wind_speed_10m"]), let direction = JSONField.double(current["wind_direction_10m"]) {
            wind = WindEstimate(
                speedKilometersPerHour: speed,
                gustKilometersPerHour: JSONField.double(current["wind_gusts_10m"]),
                directionDegrees: direction,
                fetchedAt: .now
            )
        } else {
            wind = nil
        }

        let hourly = root["hourly"] as? [String: Any]
        let nextPrecipitationProbability = (hourly?["precipitation_probability"] as? [Any]).flatMap { values in
            values.compactMap(JSONField.double).prefix(3).max()
        }
        let pressureTrend = ((hourly?["surface_pressure"] as? [Any]) ?? []).compactMap(JSONField.double)
        let trendSummary: String
        if let first = pressureTrend.first, let last = pressureTrend.dropFirst().prefix(2).last {
            if last - first > 1.5 {
                trendSummary = "Pressure rising slightly"
            } else if first - last > 1.5 {
                trendSummary = "Pressure falling slightly"
            } else {
                trendSummary = "Conditions broadly stable"
            }
        } else {
            trendSummary = "Short-term trend unavailable"
        }

        let condition = AtmosphericCondition(
            temperatureCelsius: JSONField.double(current["temperature_2m"]),
            pressureHectopascals: JSONField.double(current["surface_pressure"]),
            humidityPercent: JSONField.double(current["relative_humidity_2m"]),
            precipitationMillimeters: JSONField.double(current["precipitation"]),
            precipitationProbabilityPercent: nextPrecipitationProbability,
            cloudCoverPercent: JSONField.double(current["cloud_cover"]),
            visibilityKilometers: JSONField.double(current["visibility"]).map { $0 / 1_000 },
            weatherCode: Int(JSONField.double(current["weather_code"]) ?? -1),
            fetchedAt: .now,
            trendSummary: trendSummary
        )

        return (wind, condition)
    }
}

actor PowerInfrastructureProvider {
    private let configuredDatasets: [PowerDatasetConfiguration]
    private let remoteDatasetProvider = RemotePowerDatasetProvider()
    private let osmFallbackProvider = OSMPowerInfrastructureProvider()

    init(configuredDatasets: [PowerDatasetConfiguration]? = nil) {
        self.configuredDatasets = configuredDatasets ?? Self.loadConfiguredDatasets()
    }

    func fetch(in region: MKCoordinateRegion) async -> PowerInfrastructureSnapshot {
        for dataset in configuredDatasets {
            if let snapshot = await remoteDatasetProvider.fetch(dataset: dataset, in: region), !snapshot.lines.isEmpty || !snapshot.structures.isEmpty {
                return snapshot
            }
        }

        return await osmFallbackProvider.fetch(in: region) ?? PowerInfrastructureSnapshot(
            lines: [],
            structures: [],
            status: "No power infrastructure returned for this viewport"
        )
    }

    nonisolated private static func loadConfiguredDatasets() -> [PowerDatasetConfiguration] {
        let environment = ProcessInfo.processInfo.environment
        var datasets: [PowerDatasetConfiguration] = []

        if let value = environment["SAPN_POWER_DATA_URL"], let dataset = datasetFromSingleValue(name: "SA Power Networks", value: value, defaultCategory: .distribution) {
            datasets.append(dataset)
        }

        if let value = environment["ELECTRANET_POWER_DATA_URL"], let dataset = datasetFromSingleValue(name: "ElectraNet", value: value, defaultCategory: .transmission) {
            datasets.append(dataset)
        }

        if let rawList = environment["POWER_DATASET_URLS"] {
            let entries = rawList.split(separator: ";").map(String.init)
            for entry in entries {
                if let dataset = datasetFromCompositeValue(entry) {
                    datasets.append(dataset)
                }
            }
        }

        return datasets
    }

    nonisolated private static func datasetFromSingleValue(name: String, value: String, defaultCategory: PowerLineCategory) -> PowerDatasetConfiguration? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        let format = inferredFormat(from: url) ?? .geoJSON
        return PowerDatasetConfiguration(name: name, url: url, format: format, defaultCategory: defaultCategory)
    }

    nonisolated private static func datasetFromCompositeValue(_ value: String) -> PowerDatasetConfiguration? {
        let parts = value.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4, let url = URL(string: parts[1]), let format = PowerDatasetConfiguration.Format(value: parts[2]) else { return nil }
        let category: PowerLineCategory = parts[3].lowercased() == "transmission" ? .transmission : .distribution
        return PowerDatasetConfiguration(name: parts[0], url: url, format: format, defaultCategory: category)
    }

    nonisolated private static func inferredFormat(from url: URL) -> PowerDatasetConfiguration.Format? {
        let path = url.path.lowercased()
        if path.hasSuffix(".geojson") || path.hasSuffix(".json") {
            return .geoJSON
        }
        if path.hasSuffix(".kml") {
            return .kml
        }
        return nil
    }
}

actor FIRMSFireProvider {
    private let session = URLSession(configuration: .ephemeral)
    private let dataSources = [
        ("VIIRS_SNPP_NRT", "VIIRS"),
        ("VIIRS_NOAA20_NRT", "VIIRS"),
        ("VIIRS_NOAA21_NRT", "VIIRS"),
        ("MODIS_NRT", "MODIS")
    ]

    func fetch(in region: MKCoordinateRegion) async -> FireFetchResult {
        guard let mapKey = ProcessInfo.processInfo.environment["FIRMS_MAP_KEY"], !mapKey.isEmpty else {
            return FireFetchResult(detections: [], status: "Set FIRMS_MAP_KEY to enable NASA FIRMS fire detections")
        }

        var detections: [FireDetection] = []

        await withTaskGroup(of: [FireDetection].self) { group in
            for (dataset, label) in dataSources {
                group.addTask { [session] in
                    await Self.fetchDataset(session: session, mapKey: mapKey, dataset: dataset, label: label, region: region)
                }
            }

            for await result in group {
                detections.append(contentsOf: result)
            }
        }

        return FireFetchResult(
            detections: detections,
            status: detections.isEmpty ? "No recent FIRMS detections in this viewport" : "NASA FIRMS hotspot layer (\(detections.count) detections)"
        )
    }

    private static func fetchDataset(session: URLSession, mapKey: String, dataset: String, label: String, region: MKCoordinateRegion) async -> [FireDetection] {
        guard let url = areaURL(mapKey: mapKey, dataset: dataset, region: region) else { return [] }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
            return parseCSV(data: data, sourceLabel: label, dataset: dataset)
        } catch {
            return []
        }
    }

    private static func areaURL(mapKey: String, dataset: String, region: MKCoordinateRegion) -> URL? {
        let south = region.center.latitude - region.span.latitudeDelta / 2
        let north = region.center.latitude + region.span.latitudeDelta / 2
        let west = region.center.longitude - region.span.longitudeDelta / 2
        let east = region.center.longitude + region.span.longitudeDelta / 2
        let area = "\(west),\(south),\(east),\(north)"
        let areaComponent = area.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? area
        return URL(string: "https://firms.modaps.eosdis.nasa.gov/api/area/csv/\(mapKey)/\(dataset)/\(areaComponent)/1")
    }

    nonisolated private static func parseCSV(data: Data, sourceLabel: String, dataset: String) -> [FireDetection] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let rows = text.split(whereSeparator: \.isNewline)
        guard let headerLine = rows.first else { return [] }
        let headers = headerLine.split(separator: ",").map(String.init)

        return rows.dropFirst().compactMap { row in
            let values = CSVParser.fields(from: String(row))
            guard values.count == headers.count else { return nil }
            let record = Dictionary(uniqueKeysWithValues: zip(headers, values))

            guard
                let latitude = Double(record["latitude"] ?? ""),
                let longitude = Double(record["longitude"] ?? ""),
                let detectedAt = parseTimestamp(date: record["acq_date"], time: record["acq_time"])
            else {
                return nil
            }

            let confidence = confidenceLevel(record: record, dataset: dataset)
            let brightness = Double(record["bright_ti4"] ?? "") ?? Double(record["brightness"] ?? "")
            let frp = Double(record["frp"] ?? "")

            return FireDetection(
                id: "\(dataset)-\(latitude)-\(longitude)-\(record["acq_date"] ?? "")-\(record["acq_time"] ?? "")",
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                detectedAt: detectedAt,
                source: sourceLabel,
                confidence: confidence,
                brightness: brightness,
                frp: frp
            )
        }
    }

    nonisolated private static func parseTimestamp(date: String?, time: String?) -> Date? {
        guard let date, let time else { return nil }
        let padded = String(time).leftPadding(toLength: 4, withPad: "0")
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return formatter.date(from: "\(date) \(padded)")
    }

    nonisolated private static func confidenceLevel(record: [String: String], dataset: String) -> FireConfidenceLevel {
        if dataset.contains("VIIRS"), let confidence = record["confidence"]?.lowercased() {
            switch confidence {
            case "h":
                return .high
            case "n":
                return .medium
            default:
                return .low
            }
        }

        let value = Int(record["confidence"] ?? "") ?? 0
        switch value {
        case 0..<30:
            return FireConfidenceLevel.low
        case 30..<80:
            return FireConfidenceLevel.medium
        default:
            return FireConfidenceLevel.high
        }
    }
}

actor NAIPSNotamProvider {
    private let session = URLSession(configuration: .ephemeral)

    func fetchBriefingText(around location: CLLocation?) async -> NOTAMFetchResult? {
        guard let base = ProcessInfo.processInfo.environment["AIRSERVICES_NOTAM_TEXT_URL"], let url = URL(string: base) else {
            return NOTAMFetchResult(rawText: "", status: "Paste NOTAM briefing text manually, or configure AIRSERVICES_NOTAM_TEXT_URL for automated retrieval")
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let location {
            var queryItems = components?.queryItems ?? []
            queryItems += [
                URLQueryItem(name: "lat", value: String(location.coordinate.latitude)),
                URLQueryItem(name: "lon", value: String(location.coordinate.longitude))
            ]
            components?.queryItems = queryItems
        }

        guard let finalURL = components?.url else {
            return NOTAMFetchResult(rawText: "", status: "Automated NOTAM URL is invalid")
        }

        do {
            let (data, response) = try await session.data(from: finalURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return NOTAMFetchResult(rawText: "", status: "Automated NOTAM fetch unavailable")
            }
            let text = String(decoding: data, as: UTF8.self)
            return NOTAMFetchResult(rawText: text, status: text.isEmpty ? "Automated NOTAM source returned no text" : "Automated NOTAM briefing loaded")
        } catch {
            return NOTAMFetchResult(rawText: "", status: "Automated NOTAM fetch failed")
        }
    }
}

nonisolated enum NOTAMParser {
    static func parse(rawText: String) -> [StructuredNOTAM] {
        let chunks = rawText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return chunks.compactMap(parseChunk)
    }

    private static func parseChunk(_ chunk: String) -> StructuredNOTAM? {
        let reference = extract(pattern: #"([A-Z]\d{4}/\d{2})"#, from: chunk) ?? UUID().uuidString
        let geometry = parseGeometry(from: chunk)
        let altitudeBand = parseAltitudeBand(from: chunk)
        let validFrom = parseDate(code: extract(pattern: #"B\)\s*(\d{10})"#, from: chunk))
        let validUntil = parseDate(code: extract(pattern: #"C\)\s*(\d{10})"#, from: chunk))
        let kind = parseKind(from: chunk)
        let summary = chunk
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: "E)")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(100) ?? ""

        guard geometry != nil || chunk.contains("Q)") || chunk.contains("E)") else { return nil }

        return StructuredNOTAM(
            id: reference,
            reference: reference,
            kind: kind,
            geometry: geometry,
            altitudeBand: altitudeBand,
            validFrom: validFrom,
            validUntil: validUntil,
            originalText: chunk,
            summary: String(summary)
        )
    }

    private static func parseKind(from chunk: String) -> NotamKind {
        let upper = chunk.uppercased()
        if upper.contains("RESTRICTED") || upper.contains("RA ") || upper.contains("/QRR") {
            return .restricted
        }
        if upper.contains("HAZARD") || upper.contains("FIRE") || upper.contains("UAS") {
            return .hazard
        }
        if upper.contains("AIRSPACE") || upper.contains("CTR") || upper.contains("CTA") {
            return .airspaceChange
        }
        return .caution
    }

    private static func parseGeometry(from chunk: String) -> NotamGeometry? {
        if
            let centerToken = extract(pattern: #"(\d{4,6}[NS]\d{5,7}[EW])"#, from: chunk),
            let center = parseCoordinate(centerToken),
            let radiusValue = extract(pattern: #"(\d+(?:\.\d+)?)\s*NM"#, from: chunk),
            let radiusNM = Double(radiusValue)
        {
            return .circle(center: center, radiusMeters: radiusNM * 1_852)
        }

        let matches = matches(pattern: #"\d{4,6}[NS]\d{5,7}[EW]"#, in: chunk)
        let coordinates = matches.compactMap(parseCoordinate)
        if coordinates.count >= 3 {
            return .polygon(coordinates: coordinates)
        }

        return nil
    }

    private static func parseAltitudeBand(from chunk: String) -> NotamAltitudeBand {
        let upper = chunk.uppercased()
        let sfcTo = extract(pattern: #"SFC[- ]?(\d{3,5})\s*FT"#, from: upper)
        if let upperFeet = sfcTo.flatMap(Double.init) {
            return NotamAltitudeBand(lowerFeet: 0, upperFeet: upperFeet)
        }

        let range = extract(pattern: #"(\d{3,5})\s*FT.*?(\d{3,5})\s*FT"#, from: upper)
        if let range {
            let values = matches(pattern: #"\d{3,5}"#, in: range).compactMap(Double.init)
            if values.count >= 2 {
                return NotamAltitudeBand(lowerFeet: values[0], upperFeet: values[1])
            }
        }

        return NotamAltitudeBand(lowerFeet: 0, upperFeet: 5_000)
    }

    private static func parseDate(code: String?) -> Date? {
        guard let code else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyMMddHHmm"
        return formatter.date(from: code)
    }

    private static func parseCoordinate(_ token: String) -> CLLocationCoordinate2D? {
        let pattern = #"(\d{2})(\d{2})(\d{0,2})([NS])(\d{3})(\d{2})(\d{0,2})([EW])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(token.startIndex..<token.endIndex, in: token)
        guard let match = regex.firstMatch(in: token, range: nsRange) else { return nil }

        func component(_ index: Int) -> String {
            guard let range = Range(match.range(at: index), in: token) else { return "" }
            return String(token[range])
        }

        let latDeg = Double(component(1)) ?? 0
        let latMin = Double(component(2)) ?? 0
        let latSec = Double(component(3)) ?? 0
        let latHem = component(4)
        let lonDeg = Double(component(5)) ?? 0
        let lonMin = Double(component(6)) ?? 0
        let lonSec = Double(component(7)) ?? 0
        let lonHem = component(8)

        var latitude = latDeg + latMin / 60 + latSec / 3600
        var longitude = lonDeg + lonMin / 60 + lonSec / 3600
        if latHem == "S" { latitude *= -1 }
        if lonHem == "W" { longitude *= -1 }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func extract(pattern: String, from text: String) -> String? {
        matches(pattern: pattern, in: text).first
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            let captureIndex = match.numberOfRanges > 1 ? 1 : 0
            guard let captureRange = Range(match.range(at: captureIndex), in: text) else { return nil }
            return String(text[captureRange])
        }
    }
}

actor RemotePowerDatasetProvider {
    private let session = URLSession(configuration: .ephemeral)

    func fetch(dataset: PowerDatasetConfiguration, in region: MKCoordinateRegion) async -> PowerInfrastructureSnapshot? {
        do {
            let data = try await data(for: dataset.url)

            switch dataset.format {
            case .geoJSON:
                return try parseGeoJSON(data: data, dataset: dataset, region: region)
            case .kml:
                return parseKML(data: data, dataset: dataset, region: region)
            }
        } catch {
            return nil
        }
    }

    private func data(for url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    nonisolated private func parseGeoJSON(data: Data, dataset: PowerDatasetConfiguration, region: MKCoordinateRegion) throws -> PowerInfrastructureSnapshot {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let features = root["features"] as? [[String: Any]]
        else {
            return PowerInfrastructureSnapshot(lines: [], structures: [], status: "\(dataset.name) returned no GeoJSON features")
        }

        var lines: [PowerLineFeature] = []
        var structures: [PowerStructure] = []

        for feature in features {
            guard
                let geometry = feature["geometry"] as? [String: Any],
                let type = geometry["type"] as? String
            else {
                continue
            }

            let properties = feature["properties"] as? [String: Any] ?? [:]
            switch type {
            case "LineString":
                let coordinates = GeoParser.coordinates(from: geometry["coordinates"])
                guard coordinates.count >= 2, coordinates.contains(where: { region.contains($0) }) else { continue }
                let category = GeoParser.category(from: properties) ?? dataset.defaultCategory
                lines.append(PowerLineFeature(
                    id: JSONField.string(properties["id"]) ?? UUID().uuidString,
                    coordinates: coordinates,
                    category: category,
                    source: dataset.name
                ))
            case "Point":
                guard
                    let coordinate = GeoParser.singleCoordinate(from: geometry["coordinates"]),
                    region.contains(coordinate)
                else {
                    continue
                }
                structures.append(PowerStructure(
                    id: JSONField.string(properties["id"]) ?? UUID().uuidString,
                    coordinate: coordinate,
                    kind: JSONField.string(properties["power"]) ?? "structure",
                    source: dataset.name
                ))
            default:
                continue
            }
        }

        return PowerInfrastructureSnapshot(lines: lines, structures: structures, status: "\(dataset.name) official dataset")
    }

    nonisolated private func parseKML(data: Data, dataset: PowerDatasetConfiguration, region: MKCoordinateRegion) -> PowerInfrastructureSnapshot {
        guard let text = String(data: data, encoding: .utf8) else {
            return PowerInfrastructureSnapshot(lines: [], structures: [], status: "\(dataset.name) KML unreadable")
        }

        let lineMatches = GeoParser.matches(in: text, pattern: "<LineString>.*?<coordinates>(.*?)</coordinates>.*?</LineString>")
        let pointMatches = GeoParser.matches(in: text, pattern: "<Point>.*?<coordinates>(.*?)</coordinates>.*?</Point>")

        let lines = lineMatches.compactMap { match -> PowerLineFeature? in
            let coordinates = GeoParser.kmlCoordinates(from: match)
            guard coordinates.count >= 2, coordinates.contains(where: { region.contains($0) }) else { return nil }
            return PowerLineFeature(id: UUID().uuidString, coordinates: coordinates, category: dataset.defaultCategory, source: dataset.name)
        }

        let structures = pointMatches.compactMap { match -> PowerStructure? in
            guard let coordinate = GeoParser.kmlCoordinates(from: match).first, region.contains(coordinate) else { return nil }
            return PowerStructure(id: UUID().uuidString, coordinate: coordinate, kind: "tower", source: dataset.name)
        }

        return PowerInfrastructureSnapshot(lines: lines, structures: structures, status: "\(dataset.name) KML dataset")
    }
}

actor OSMPowerInfrastructureProvider {
    private let session = URLSession(configuration: .ephemeral)

    func fetch(in region: MKCoordinateRegion) async -> PowerInfrastructureSnapshot? {
        guard let request = overpassRequest(for: region) else { return nil }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return PowerInfrastructureSnapshot(lines: [], structures: [], status: "OSM fallback unavailable")
            }
            return try parseOverpass(data: data)
        } catch {
            return PowerInfrastructureSnapshot(lines: [], structures: [], status: "OSM fallback request failed")
        }
    }

    private func overpassRequest(for region: MKCoordinateRegion) -> URLRequest? {
        let south = region.center.latitude - region.span.latitudeDelta / 2
        let north = region.center.latitude + region.span.latitudeDelta / 2
        let west = region.center.longitude - region.span.longitudeDelta / 2
        let east = region.center.longitude + region.span.longitudeDelta / 2
        let query = """
        [out:json][timeout:20];
        (
          way["power"~"^(line|minor_line)$"](\(south),\(west),\(north),\(east));
          node["power"~"^(tower|pole)$"](\(south),\(west),\(north),\(east));
        );
        out body geom;
        """

        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return request
    }

    nonisolated private func parseOverpass(data: Data) throws -> PowerInfrastructureSnapshot {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let elements = root["elements"] as? [[String: Any]]
        else {
            return PowerInfrastructureSnapshot(lines: [], structures: [], status: "OSM fallback returned no elements")
        }

        var lines: [PowerLineFeature] = []
        var structures: [PowerStructure] = []

        for element in elements {
            guard let type = element["type"] as? String else { continue }
            let tags = element["tags"] as? [String: Any] ?? [:]

            if type == "way" {
                guard let geometry = element["geometry"] as? [[String: Any]] else { continue }
                let coordinates = geometry.compactMap { point -> CLLocationCoordinate2D? in
                    guard let latitude = JSONField.double(point["lat"]), let longitude = JSONField.double(point["lon"]) else { return nil }
                    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                }
                guard coordinates.count >= 2 else { continue }
                let powerTag = JSONField.string(tags["power"]) ?? "line"
                let voltage = JSONField.double(tags["voltage"])
                let category: PowerLineCategory = powerTag == "line" || (voltage ?? 0) >= 33_000 ? .transmission : .distribution
                lines.append(PowerLineFeature(
                    id: String(element["id"] as? Int ?? lines.count),
                    coordinates: coordinates,
                    category: category,
                    source: "OpenStreetMap fallback"
                ))
            } else if type == "node" {
                guard
                    let latitude = JSONField.double(element["lat"]),
                    let longitude = JSONField.double(element["lon"])
                else {
                    continue
                }
                structures.append(PowerStructure(
                    id: String(element["id"] as? Int ?? structures.count),
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    kind: JSONField.string(tags["power"]) ?? "tower",
                    source: "OpenStreetMap fallback"
                ))
            }
        }

        return PowerInfrastructureSnapshot(
            lines: lines,
            structures: structures,
            status: "OSM fallback layer (\(lines.count) lines, \(structures.count) structures)"
        )
    }
}

nonisolated enum GeoParser {
    static func coordinates(from value: Any?) -> [CLLocationCoordinate2D] {
        guard let raw = value as? [[Double]] else { return [] }
        return raw.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
    }

    static func singleCoordinate(from value: Any?) -> CLLocationCoordinate2D? {
        guard let pair = value as? [Double], pair.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
    }

    static func category(from properties: [String: Any]) -> PowerLineCategory? {
        if let voltage = JSONField.double(properties["voltage"]), voltage >= 33_000 {
            return .transmission
        }
        if let kind = JSONField.string(properties["power"]), kind == "line" {
            return .transmission
        }
        if let kind = JSONField.string(properties["power"]), kind == "minor_line" {
            return .distribution
        }
        return nil
    }

    static func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let capture = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[capture])
        }
    }

    static func kmlCoordinates(from text: String) -> [CLLocationCoordinate2D] {
        text
            .split(whereSeparator: \.isWhitespace)
            .compactMap { token in
                let parts = token.split(separator: ",")
                guard parts.count >= 2, let longitude = Double(parts[0]), let latitude = Double(parts[1]) else { return nil }
                return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
    }
}

nonisolated enum CSVParser {
    static func fields(from row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var insideQuotes = false

        for character in row {
            if character == "\"" {
                insideQuotes.toggle()
            } else if character == "," && !insideQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        fields.append(current)
        return fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

nonisolated extension MKCoordinateRegion {
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let latitudeRange = (center.latitude - span.latitudeDelta / 2) ... (center.latitude + span.latitudeDelta / 2)
        let longitudeRange = (center.longitude - span.longitudeDelta / 2) ... (center.longitude + span.longitudeDelta / 2)
        return latitudeRange.contains(coordinate.latitude) && longitudeRange.contains(coordinate.longitude)
    }
}

nonisolated extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        if count >= toLength { return self }
        return String(repeating: String(character), count: toLength - count) + self
    }
}

nonisolated extension Double {
    var cleanFeetDisplayLabel: String {
        "\(Int(self)) ft"
    }
}

nonisolated enum JSONField {
    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            number.doubleValue
        case let text as String:
            Double(text)
        default:
            nil
        }
    }

    static func string(_ value: Any?) -> String? {
        switch value {
        case let text as String:
            text
        case let number as NSNumber:
            number.stringValue
        default:
            nil
        }
    }
}
