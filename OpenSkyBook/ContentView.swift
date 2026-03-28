import MapKit
import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var model: AircraftAwarenessModel
    private let onShowDisclaimer: () -> Void

    init() {
        _model = StateObject(wrappedValue: AircraftAwarenessModel())
        onShowDisclaimer = {}
    }

    init(model: AircraftAwarenessModel, onShowDisclaimer: @escaping () -> Void = {}) {
        _model = StateObject(wrappedValue: model)
        self.onShowDisclaimer = onShowDisclaimer
    }

    init(onShowDisclaimer: @escaping () -> Void) {
        _model = StateObject(wrappedValue: AircraftAwarenessModel())
        self.onShowDisclaimer = onShowDisclaimer
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            mapPanel
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1180, minHeight: 760)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                locationSection
                headingSection
                sourceSection
                filterSection
                layerManagerSection
                if model.showWindPanel {
                    windSection
                }
                if model.showWeatherPanel {
                    weatherSection
                }
                notamSection
                powerSection
                fireSection
                safetySection
                alertSection
                aircraftSection
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Source")
                .font(.title2.weight(.semibold))

            Picker("Mode", selection: $model.sourcePreference) {
                ForEach(DataSourcePreference.allCases) { preference in
                    Text(preference.label).tag(preference)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("Active feed", value: model.activeSourceStatus)
            LabeledContent("Health", value: model.sourceHealthSummary)
            Text(model.sourceDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var headingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Heading")
                .font(.title3.weight(.semibold))

            Toggle("Show heading display", isOn: $model.showHeadingDisplay)

            Picker("Map orientation", selection: $model.mapOrientationMode) {
                ForEach(MapOrientationMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!model.hasReliableHeading)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Smoothing")
                    Spacer()
                    Text("\(Int(model.headingSmoothingFactor * 100))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.headingSmoothingFactor, in: 0.1 ... 0.95, step: 0.05)
            }

            LabeledContent("Current", value: model.headingDisplayText)
            LabeledContent("Source", value: model.headingSourceSummary)
            Text(model.headingStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let message = model.headingCalibrationMessage {
                warningRow(text: message, tint: .orange)
            }

            if model.isUsingMapOrientationFallback {
                Text("North-up fallback active. Forward means map-up only.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            Text(model.headingComparisonSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(model.headingFallbackSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Location")
                .font(.title3.weight(.semibold))

            Picker("Location Source", selection: $model.locationSourcePreference) {
                ForEach(LocationSourcePreference.allCases) { preference in
                    Text(preference.label).tag(preference)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("Current coordinates", value: model.locationSummary)
            Toggle("Show wind panel", isOn: $model.showWindPanel)

            if model.locationSourcePreference == .manualCoordinates {
                HStack {
                    TextField("Latitude", text: $model.manualLatitude)
                        .textFieldStyle(.roundedBorder)
                    TextField("Longitude", text: $model.manualLongitude)
                        .textFieldStyle(.roundedBorder)
                    Button("Apply") {
                        model.applyManualCoordinates()
                    }
                }

                Text(model.manualCoordinateSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filters")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Alert radius")
                    Spacer()
                    Text("\(model.alertRadiusKilometers, specifier: "%.1f") km")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.alertRadiusKilometers, in: 1 ... 20, step: 0.5)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Altitude threshold")
                    Spacer()
                    Text("\(Int(model.altitudeThresholdFeet)) ft AGL")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.altitudeThresholdFeet, in: 200 ... 5000, step: 100)
            }

            Toggle("Hide high-altitude traffic", isOn: $model.hideHighAltitudeTraffic)
            Toggle("Keep map centered on user", isOn: $model.followUser)
        }
    }

    private var layerManagerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layers")
                .font(.title3.weight(.semibold))

            Picker("Base map", selection: $model.mapPresentation) {
                ForEach(MapPresentation.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .pickerStyle(.menu)

            if let warning = model.layerDensityWarning {
                Text(warning)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            Picker("Preset", selection: $model.selectedPreset) {
                ForEach(LayerPresetMode.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            Button("Apply Preset") {
                model.applyPreset(model.selectedPreset)
            }

            Picker("Startup Mode", selection: $model.startupPreset) {
                ForEach(LayerPresetMode.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.menu)

            Toggle("Clean mode", isOn: Binding(
                get: { model.isCleanModeEnabled },
                set: { _ in model.toggleCleanMode() }
            ))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Quick opacity")
                    Spacer()
                    Text("\(Int(model.quickLayerOpacity * 100))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.quickLayerOpacity, in: 0.4 ... 1, step: 0.05)
            }

            ForEach(Array(model.orderedLayerConfigurations.enumerated()), id: \.element.kind) { _, configuration in
                layerManagerRow(configuration)
            }
        }
    }

    private var alertSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alerts")
                .font(.title3.weight(.semibold))

            Toggle("Audio alert", isOn: $model.audioAlertsEnabled)
            Toggle("Voice alerts", isOn: $model.voiceAlertsEnabled)
                .disabled(!model.audioAlertsEnabled)

            Picker("Alert type", selection: $model.trafficAlertMode) {
                ForEach(TrafficAlertMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!model.audioAlertsEnabled)

            Picker("Sensitivity", selection: $model.trafficAlertSensitivity) {
                ForEach(TrafficAlertSensitivity.allCases) { sensitivity in
                    Text(sensitivity.label).tag(sensitivity)
                }
            }
            .pickerStyle(.segmented)

            Picker("Alert sound", selection: $model.trafficAlertSound) {
                ForEach(TrafficAlertSound.allCases) { sound in
                    Text(sound.label).tag(sound)
                }
            }
            .pickerStyle(.menu)
            .disabled(!model.audioAlertsEnabled)

            if model.trafficAlertSound == .custom {
                TextField("Custom sound path", text: $model.customTrafficAlertSoundPath)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Traffic radius")
                    Spacer()
                    Text("\(formatted(model.trafficAlertDistanceKilometers, decimals: 1)) km")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.trafficAlertDistanceKilometers, in: 1 ... 10, step: 0.5)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Traffic altitude")
                    Spacer()
                    Text("\(Int(model.trafficAlertAltitudeFeet)) ft AGL")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.trafficAlertAltitudeFeet, in: 200 ... 3000, step: 100)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Alert volume")
                    Spacer()
                    Text("\(Int(model.trafficAlertVolume * 100))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.trafficAlertVolume, in: 0 ... 1, step: 0.05)
                    .disabled(!model.audioAlertsEnabled)
            }

            Toggle("Only approaching traffic", isOn: $model.requireApproachingTraffic)
            Toggle("Only descending traffic", isOn: $model.requireDescendingTraffic)

            Text(model.trafficAlertStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(model.trafficAlertDisclaimer)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            if let powerWarning = model.powerWarningMessage {
                warningRow(text: powerWarning, tint: .orange)
            }

            if let fireWarning = model.fireWarningMessage {
                warningRow(text: fireWarning, tint: .red)
            }

            if let weatherWarning = model.weatherWarningMessage {
                warningRow(text: weatherWarning, tint: .blue)
            }

            if let notamWarning = model.notamWarningMessage {
                warningRow(text: notamWarning, tint: .purple)
            }

            if model.alertingAircraft.isEmpty {
                Text("No traffic meets the configured audible alert criteria.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.alertingAircraft.prefix(4)) { aircraft in
                    alertRow(for: aircraft)
                }
            }
        }
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Safety")
                .font(.title3.weight(.semibold))

            HStack {
                riskBadge
                Spacer()
                Text(model.safetyAssessment.readinessText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(model.safetyAssessment.readyToFly ? .green : .orange)
            }

            Text("Dynamic score updates from traffic, weather, NOTAMs, signal, and flight planning inputs.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            telemetryControls

            Group {
                advisoryRow(title: "Terrain", detail: model.safetyAssessment.terrainStatus)
                advisoryRow(title: "Signal", detail: model.safetyAssessment.signalStatus)
                advisoryRow(title: "RTH", detail: model.safetyAssessment.rthStatus)
                advisoryRow(title: "Light", detail: model.safetyAssessment.lightStatus)
                advisoryRow(title: "Geofence", detail: model.safetyAssessment.geofenceStatus)
            }

            Text("Checklist")
                .font(.subheadline.weight(.semibold))

            ForEach(model.safetyAssessment.checklist) { item in
                checklistRow(item)
            }

            if !model.safetyAssessment.prioritizedAlerts.isEmpty {
                Text("Prioritized Alerts")
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(model.safetyAssessment.prioritizedAlerts.enumerated()), id: \.offset) { _, alert in
                    warningRow(text: alert, tint: .red)
                }
            }

            if !model.safetyAssessment.changes.isEmpty {
                Text("Changes")
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(model.safetyAssessment.changes.enumerated()), id: \.offset) { _, change in
                    Text(change)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Risk Breakdown")
                .font(.subheadline.weight(.semibold))

            ForEach(model.safetyAssessment.factors) { factor in
                riskFactorRow(factor)
            }

            Toggle("Advanced weighting", isOn: $model.showAdvancedSafetyWeights)

            if model.showAdvancedSafetyWeights {
                advancedWeightControls
            }
        }
    }

    private var fireSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fire Detection")
                .font(.title3.weight(.semibold))

            Toggle("Show fire layer", isOn: $model.showFireLayer)
            Toggle("Fire audio alert", isOn: $model.fireAudioAlertsEnabled)
            Toggle("Show timestamp and intensity", isOn: $model.showFireDetails)

            HStack {
                Text("Recency")
                Spacer()
                Picker("Recency", selection: $model.fireRecencyFilter) {
                    ForEach(FireRecencyFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            HStack {
                Text("Min confidence")
                Spacer()
                Picker("Confidence", selection: $model.minimumFireConfidence) {
                    ForEach(FireConfidenceLevel.allCases) { confidence in
                        Text(confidence.label).tag(confidence)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Alert radius")
                    Spacer()
                    Text("\(formatted(model.fireAlertRadiusKilometers, decimals: 1)) km")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.fireAlertRadiusKilometers, in: 1 ... 25, step: 0.5)
            }

            Text(model.fireDisclaimer)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Detections may be several minutes to hours old and not all fires are detected immediately.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(model.fireStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var powerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Power Infrastructure")
                .font(.title3.weight(.semibold))

            Toggle("Show power infrastructure", isOn: $model.showPowerInfrastructure)
            Toggle("Show towers and poles", isOn: $model.showPowerStructures)
            Toggle("Powerline audio alert", isOn: $model.powerAudioAlertsEnabled)
            Toggle("Projected flight path warning", isOn: $model.projectedFlightPathEnabled)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Safety buffer")
                    Spacer()
                    Text("\(Int(model.powerBufferMeters)) m")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.powerBufferMeters, in: 20 ... 50, step: 5)
            }

            if model.projectedFlightPathEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Path distance")
                        Spacer()
                        Text("\(Int(model.projectedFlightDistanceMeters)) m")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $model.projectedFlightDistanceMeters, in: 100 ... 1000, step: 50)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Path bearing")
                        Spacer()
                        Text("\(Int(model.projectedFlightBearingDegrees))°")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $model.projectedFlightBearingDegrees, in: 0 ... 359, step: 1)
                }
            }

            Text(model.powerDisclaimer)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(model.powerStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var windSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wind")
                .font(.title3.weight(.semibold))

            Toggle("Wind direction arrow on map", isOn: $model.showWindOverlay)

            if let wind = model.windEstimate {
                Text("Estimated wind (weather data)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                LabeledContent("Speed", value: "\(formatted(wind.speedKilometersPerHour, decimals: 0)) km/h")
                LabeledContent("Gusts", value: wind.gustKilometersPerHour.map { "\(formatted($0, decimals: 0)) km/h" } ?? "Unavailable")
                LabeledContent("Direction", value: "\(formatted(wind.directionDegrees, decimals: 0))° \(wind.directionCompass)")
            } else {
                Text("Estimated wind (weather data)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(model.windStatus)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weather")
                .font(.title3.weight(.semibold))

            Toggle("Show weather panel", isOn: $model.showWeatherPanel)
            Toggle("Weather map overlay", isOn: $model.showWeatherOverlay)
            Toggle("Weather audio alert", isOn: $model.weatherAudioAlertsEnabled)

            HStack {
                Text("High wind alert")
                Spacer()
                Text("\(formatted(model.weatherHighWindThresholdKilometersPerHour, decimals: 0)) km/h")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $model.weatherHighWindThresholdKilometersPerHour, in: 15 ... 60, step: 1)

            HStack {
                Text("Rain alert")
                Spacer()
                Text("\(formatted(model.weatherRainThresholdMillimeters, decimals: 1)) mm")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $model.weatherRainThresholdMillimeters, in: 0.1 ... 3, step: 0.1)

            HStack {
                Text("Low visibility alert")
                Spacer()
                Text("\(formatted(model.weatherLowVisibilityThresholdKilometers, decimals: 1)) km")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $model.weatherLowVisibilityThresholdKilometers, in: 1 ... 10, step: 0.5)

            Group {
                Toggle("Show temperature", isOn: $model.showTemperature)
                Toggle("Show pressure", isOn: $model.showPressure)
                Toggle("Show humidity", isOn: $model.showHumidity)
                Toggle("Show precipitation", isOn: $model.showPrecipitation)
                Toggle("Show cloud cover", isOn: $model.showCloudCover)
                Toggle("Show visibility", isOn: $model.showVisibility)
            }

            if let weather = model.weatherCondition {
                Text(model.weatherDisclaimer)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                if model.showTemperature, let value = weather.temperatureCelsius {
                    LabeledContent("Temperature", value: "\(formatted(value, decimals: 1)) °C")
                }
                if model.showPressure, let value = weather.pressureHectopascals {
                    LabeledContent("Pressure", value: "\(formatted(value, decimals: 0)) hPa")
                }
                if model.showHumidity, let value = weather.humidityPercent {
                    LabeledContent("Humidity", value: "\(formatted(value, decimals: 0)) %")
                }
                if model.showPrecipitation {
                    let precip = weather.precipitationMillimeters.map { "\(formatted($0, decimals: 1)) mm" } ?? "Unavailable"
                    let probability = weather.precipitationProbabilityPercent.map { "\(formatted($0, decimals: 0)) %" } ?? "Unavailable"
                    LabeledContent("Precipitation", value: "\(precip) / \(probability)")
                }
                if model.showCloudCover, let value = weather.cloudCoverPercent {
                    LabeledContent("Cloud cover", value: "\(formatted(value, decimals: 0)) %")
                }
                if model.showVisibility, let value = weather.visibilityKilometers {
                    LabeledContent("Visibility", value: "\(formatted(value, decimals: 1)) km")
                }

                Text(weather.trendSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Wind remains in the separate wind module.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(model.weatherDisclaimer)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(model.weatherStatus)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notamSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOTAM")
                .font(.title3.weight(.semibold))

            Toggle("Show NOTAM layer", isOn: $model.showNotamLayer)
            Toggle("NOTAM audio alert", isOn: $model.notamAudioAlertsEnabled)

            Picker("Display", selection: $model.notamDisplayMode) {
                ForEach(NotamDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Alert radius")
                Spacer()
                Text("\(formatted(model.notamAlertRadiusKilometers, decimals: 0)) km")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $model.notamAlertRadiusKilometers, in: 5 ... 50, step: 1)

            HStack {
                Text("Altitude relevance")
                Spacer()
                Text("\(Int(model.notamAltitudeThresholdFeet)) ft")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $model.notamAltitudeThresholdFeet, in: 500 ... 10000, step: 100)

            HStack {
                Text("Planned altitude")
                Spacer()
                Text("\(Int(model.notamPlannedAltitudeFeet)) ft")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $model.notamPlannedAltitudeFeet, in: 100 ... 5000, step: 50)

            Text(model.notamDisclaimer)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $model.notamRawInput)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2))
                )

            HStack {
                Button("Parse NOTAM Text") {
                    model.parseManualNOTAMInput()
                }

                Spacer()

                Text(model.notamStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(model.visibleNOTAMs.prefix(4)) { notam in
                notamSummaryRow(notam)
            }
        }
    }

    private var aircraftSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Traffic")
                .font(.title3.weight(.semibold))

            if model.displayedAircraft.isEmpty {
                Text("No aircraft currently visible from the selected feed.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.displayedAircraft.prefix(10)) { aircraft in
                    aircraftRow(for: aircraft)
                }
            }
        }
    }

    private var mapPanel: some View {
        ZStack(alignment: .top) {
            Map(position: $model.cameraPosition) {
                if let coordinate = model.userCoordinate {
                    UserAnnotation()
                    MapCircle(center: coordinate, radius: model.alertRadiusMeters)
                        .foregroundStyle(.blue.opacity(0.14))
                    if model.headingConeCoordinates.count >= 3 {
                        MapPolygon(coordinates: model.headingConeCoordinates)
                            .foregroundStyle(.cyan.opacity(0.12))
                            .stroke(.cyan.opacity(0.45), lineWidth: 2)
                        Annotation("Heading", coordinate: coordinate, anchor: .center) {
                            HeadingIndicatorView(headingDegrees: model.headingDegrees ?? 0)
                        }
                    }
                }
                orderedOverlayContent
            }
            .mapStyle(model.mapPresentation.mapStyle)
            .onMapCameraChange(frequency: .onEnd) { context in
                model.updateVisibleRegion(context.region)
            }
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        if value.translation.height > 70 {
                            model.collapseOverlayState()
                        } else if value.translation.height < -70 {
                            model.restoreOverlayStateAfterCleanMode()
                        }
                    }
            )
            .mapControls {
                MapCompass()
                MapScaleView()
                MapPitchToggle()
                MapUserLocationButton()
            }
            .overlay(alignment: .topLeading) {
                quickLayersPanel
                    .padding()
            }
            .overlay(alignment: .bottomTrailing) {
                floatingActionButtons
                    .padding()
            }

            VStack(spacing: 12) {
                topBar

                if let warning = model.primaryAlertMessage {
                    warningBanner(text: warning)
                }

                if let powerWarning = model.powerWarningMessage {
                    warningBanner(text: powerWarning, tint: .orange)
                }

                if let fireWarning = model.fireWarningMessage {
                    warningBanner(text: fireWarning, tint: .red)
                }

                if let weatherWarning = model.weatherWarningMessage {
                    warningBanner(text: weatherWarning, tint: .blue)
                }

                if let notamWarning = model.notamWarningMessage {
                    warningBanner(text: notamWarning, tint: .purple)
                }

                if model.showHeadingDisplay {
                    headingFloatingPanel
                }

                if model.showWindPanel, let wind = model.windEstimate {
                    windFloatingPanel(wind)
                }

                if model.showWeatherPanel, let weather = model.weatherCondition {
                    weatherFloatingPanel(weather)
                }
            }
            .padding()
        }
        .onLongPressGesture {
            model.toggleQuickLayersPanel()
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Label(model.mapPresentation.label, systemImage: "map")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())

            Spacer()

            Text("\(model.effectiveVisibleLayerCount) layers")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(model.alertStatusIndicator)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(model.primaryAlertMessage == nil ? Color.secondary : Color.red)

            HStack(spacing: 6) {
                Image(systemName: model.safetyAssessment.band.symbol)
                Text("\(model.safetyAssessment.score)")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(riskColor(model.safetyAssessment.band))

            Text(model.headingDisplayText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(model.locationSummary)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                onShowDisclaimer()
            } label: {
                Label("Advisory tool only", systemImage: "info.circle")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            Text(model.activeSourceStatus)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var quickLayersPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Quick Layers", systemImage: "square.3.layers.3d.top.filled")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    model.toggleQuickLayersPanel()
                } label: {
                    Image(systemName: model.isQuickLayersExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
            }

            if model.isQuickLayersExpanded {
                HStack(spacing: 8) {
                    ForEach(model.quickToggleKinds, id: \.self) { kind in
                        quickLayerButton(for: kind)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(12)
        .frame(maxWidth: 420)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var floatingActionButtons: some View {
        VStack(alignment: .trailing, spacing: 10) {
            fabButton(
                icon: model.isCleanModeEnabled ? "eye.slash.fill" : "eye.fill",
                label: "Clean",
                tint: model.isCleanModeEnabled ? .orange : .blue
            ) {
                model.toggleCleanMode()
            }

            fabButton(
                icon: "airplane.circle.fill",
                label: model.alertStatusIndicator,
                tint: model.primaryAlertMessage == nil ? .secondary : .red
            ) {}

            fabButton(
                icon: "line.3.horizontal.decrease.circle.fill",
                label: "Layers",
                tint: .primary
            ) {
                model.toggleQuickLayersPanel()
            }
        }
    }

    private func layerVisibilityBinding(for kind: MapOverlayKind) -> Binding<Bool> {
        Binding(
            get: { model.configuration(for: kind).isVisible },
            set: { model.setLayerVisibility($0, for: kind) }
        )
    }

    private func layerOpacityBinding(for kind: MapOverlayKind) -> Binding<Double> {
        Binding(
            get: { model.opacity(for: kind) },
            set: { model.setLayerOpacity($0, for: kind) }
        )
    }

    private func layerManagerRow(_ configuration: MapLayerConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Toggle(configuration.kind.label, isOn: layerVisibilityBinding(for: configuration.kind))
                    .toggleStyle(.switch)
                Spacer()
                Button {
                    model.moveLayer(configuration.kind, direction: -1)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .disabled(!model.canMoveLayer(configuration.kind, direction: -1))

                Button {
                    model.moveLayer(configuration.kind, direction: 1)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(!model.canMoveLayer(configuration.kind, direction: 1))
            }

            HStack {
                Text("Opacity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: layerOpacityBinding(for: configuration.kind), in: 0.15 ... 1)
                    .disabled(!configuration.isSupported)
                Text("\(Int(model.opacity(for: configuration.kind) * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }

            Text(model.layerStatus(for: configuration.kind))
                .font(.caption)
                .foregroundStyle(configuration.isSupported ? Color.secondary : Color.orange)
            Text(configuration.kind.advisoryNote)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func quickLayerButton(for kind: MapOverlayKind) -> some View {
        let isVisible = model.effectiveLayerVisibility(for: kind)
        return Button {
            model.setLayerVisibility(!model.configuration(for: kind).isVisible, for: kind)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: quickLayerIcon(for: kind))
                    .font(.headline)
                Text(quickLayerShortLabel(for: kind))
                    .font(.caption2.weight(.semibold))
            }
            .frame(width: 52, height: 52)
            .foregroundStyle(isVisible ? Color.white : Color.primary)
            .background(isVisible ? quickLayerTint(for: kind) : Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func fabButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }

    private func quickLayerIcon(for kind: MapOverlayKind) -> String {
        switch kind {
        case .adsbTraffic:
            "airplane.circle.fill"
        case .airspace:
            "shield.lefthalf.filled"
        case .powerInfrastructure:
            "bolt.fill"
        case .weather:
            "cloud.rain.fill"
        case .wind:
            "wind"
        case .fireDetection:
            "flame.fill"
        case .notam:
            "exclamationmark.triangle.fill"
        case .terrainElevation:
            "mountain.2.fill"
        case .landUse:
            "square.3.layers.3d.fill"
        }
    }

    private func quickLayerShortLabel(for kind: MapOverlayKind) -> String {
        switch kind {
        case .adsbTraffic:
            "ADS-B"
        case .airspace:
            "Air"
        case .powerInfrastructure:
            "Power"
        case .weather:
            "Wx"
        case .wind:
            "Wind"
        case .fireDetection:
            "Fire"
        case .notam:
            "NOTAM"
        case .terrainElevation:
            "Terr"
        case .landUse:
            "Land"
        }
    }

    private func quickLayerTint(for kind: MapOverlayKind) -> Color {
        switch kind {
        case .adsbTraffic:
            .blue
        case .airspace:
            .indigo
        case .powerInfrastructure:
            .orange
        case .weather:
            .teal
        case .wind:
            .cyan
        case .fireDetection:
            .red
        case .notam:
            .purple
        case .terrainElevation:
            .brown
        case .landUse:
            .green
        }
    }

    private var riskBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: model.safetyAssessment.band.symbol)
            Text("\(model.safetyAssessment.score)")
                .font(.headline.monospacedDigit())
            Text(model.safetyAssessment.band.label)
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(riskColor(model.safetyAssessment.band).opacity(0.14), in: Capsule())
        .foregroundStyle(riskColor(model.safetyAssessment.band))
    }

    private var telemetryControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Battery telemetry available", isOn: $model.telemetryBatteryAvailable)
            if model.telemetryBatteryAvailable {
                HStack {
                    Text("Battery")
                    Spacer()
                    Text("\(Int(model.telemetryBatteryPercent))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.telemetryBatteryPercent, in: 10 ... 100, step: 1)
            }

            Toggle("Signal telemetry available", isOn: $model.telemetrySignalAvailable)
            if model.telemetrySignalAvailable {
                HStack {
                    Text("RSSI")
                    Spacer()
                    Text("\(Int(model.telemetryRSSI)) dBm")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.telemetryRSSI, in: -110 ... -40, step: 1)

                HStack {
                    Text("Link quality")
                    Spacer()
                    Text("\(Int(model.telemetryLinkQualityPercent))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.telemetryLinkQualityPercent, in: 0 ... 100, step: 1)
            }

            HStack {
                Text("Drone altitude")
                Spacer()
                Text("\(Int(model.droneAltitudeFeet)) ft")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $model.droneAltitudeFeet, in: 100 ... 1200, step: 10)

            HStack {
                Text("RTH altitude")
                Spacer()
                Text("\(Int(model.rthAltitudeFeet)) ft")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $model.rthAltitudeFeet, in: 100 ... 800, step: 10)

            Toggle("Geofence advisory", isOn: $model.geofenceEnabled)
            if model.geofenceEnabled {
                HStack {
                    Text("Geofence radius")
                    Spacer()
                    Text("\(formatted(model.geofenceRadiusKilometers, decimals: 1)) km")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.geofenceRadiusKilometers, in: 0.5 ... 8, step: 0.1)
            }

            Toggle("NOTAM reviewed for checklist", isOn: $model.notamReviewedForChecklist)
        }
    }

    private func advisoryRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func checklistRow(_ item: SafetyChecklistItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isComplete ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func riskFactorRow(_ factor: SafetyRiskFactor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(factor.title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(factor.isAvailable ? "\(Int((factor.score * 100).rounded()))" : "N/A")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: factor.isAvailable ? factor.score : 0)
                .tint(riskColor(for: factor.score))
            Text(factor.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var advancedWeightControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            weightSlider(title: "Wind weight", value: $model.weightWind)
            weightSlider(title: "Traffic weight", value: $model.weightTraffic)
            weightSlider(title: "Airspace weight", value: $model.weightAirspace)
            weightSlider(title: "NOTAM weight", value: $model.weightNOTAM)
            weightSlider(title: "Terrain weight", value: $model.weightTerrain)
            weightSlider(title: "Signal weight", value: $model.weightSignal)
            weightSlider(title: "Weather weight", value: $model.weightWeather)
        }
    }

    private func weightSlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(formatted(value.wrappedValue, decimals: 1))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0.2 ... 2, step: 0.1)
        }
    }

    private func riskColor(_ band: SafetyRiskBand) -> Color {
        switch band {
        case .low:
            .green
        case .medium:
            .orange
        case .high:
            .red
        }
    }

    private func riskColor(for score: Double) -> Color {
        switch score {
        case 0 ..< 0.35:
            .green
        case 0.35 ..< 0.7:
            .orange
        default:
            .red
        }
    }

    private var headingFloatingPanel: some View {
        HStack(spacing: 12) {
            CompassRoseView(headingDegrees: model.headingDegrees ?? 0)
            VStack(alignment: .leading, spacing: 2) {
                Text("Directional awareness")
                    .font(.caption.weight(.semibold))
                Text("\(model.headingDisplayText) • \(model.headingSourceSummary) • \(model.mapOrientationMode.label)")
                    .font(.caption2.monospacedDigit())
                Text(model.headingComparisonSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @MapContentBuilder
    private var orderedOverlayContent: some MapContent {
        ForEach(Array(model.orderedLayerConfigurations.filter { model.effectiveLayerVisibility(for: $0.kind) }.enumerated()), id: \.element.kind) { _, configuration in
            layerContent(for: configuration.kind)
        }
    }

    @MapContentBuilder
    private func layerContent(for kind: MapOverlayKind) -> some MapContent {
        switch kind {
        case .airspace, .terrainElevation, .landUse:
            EmptyMapContent()
        case .adsbTraffic:
            if model.shouldRenderLayer(.adsbTraffic) {
                ForEach(model.renderedAircraft) { aircraft in
                    Annotation(aircraft.displayName, coordinate: aircraft.coordinate, anchor: .bottom) {
                        AircraftAnnotationView(aircraft: aircraft)
                            .opacity(model.effectiveOpacity(for: .adsbTraffic) * (aircraft.isAhead ? 1 : 0.58))
                    }
                }
            }
        case .powerInfrastructure:
            if model.shouldRenderLayer(.powerInfrastructure) {
                ForEach(model.powerLines) { line in
                    MapPolyline(coordinates: line.coordinates)
                        .stroke(powerBufferColor(for: line).opacity(0.18 * model.effectiveOpacity(for: .powerInfrastructure)), lineWidth: model.isZoomedOut ? 4 : bufferLineWidth)
                    MapPolyline(coordinates: line.coordinates)
                        .stroke(powerLineColor(for: line).opacity(model.effectiveOpacity(for: .powerInfrastructure)), lineWidth: model.isZoomedOut ? 2 : 3)
                }

                if model.projectedFlightPathCoordinates.count == 2 {
                    MapPolyline(coordinates: model.projectedFlightPathCoordinates)
                        .stroke(.cyan.opacity(0.9 * model.effectiveOpacity(for: .powerInfrastructure)), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                }

                if model.showPowerStructures {
                    ForEach(model.powerStructures) { structure in
                        Annotation(structure.kind, coordinate: structure.coordinate, anchor: .center) {
                            PowerStructureMarker(structure: structure)
                                .opacity(model.effectiveOpacity(for: .powerInfrastructure))
                        }
                    }
                }
            }
        case .weather:
            if model.shouldRenderLayer(.weather), model.showWeatherPanel, let coordinate = model.userCoordinate, let weather = model.weatherCondition {
                Annotation("Weather", coordinate: coordinate, anchor: .topTrailing) {
                    WeatherOverlayMarker(weather: weather)
                        .opacity(model.effectiveOpacity(for: .weather))
                }
            }
        case .wind:
            if model.shouldRenderLayer(.wind), model.showWindPanel, let coordinate = model.userCoordinate, let wind = model.windEstimate {
                Annotation("Wind", coordinate: coordinate, anchor: .center) {
                    WindDirectionMarker(wind: wind)
                        .opacity(model.effectiveOpacity(for: .wind))
                }
            }
        case .fireDetection:
            if model.shouldRenderLayer(.fireDetection) {
                ForEach(Array(model.fireDetections.prefix(model.isZoomedOut ? 6 : 50))) { detection in
                    Annotation(detection.source, coordinate: detection.coordinate, anchor: .center) {
                        FireDetectionMarker(detection: detection, showDetails: model.showFireDetails)
                            .opacity(model.effectiveOpacity(for: .fireDetection))
                    }
                }
            }
        case .notam:
            if model.shouldRenderLayer(.notam) {
                ForEach(model.visibleNOTAMs) { notam in
                    switch notam.geometry {
                    case let .circle(center, radiusMeters):
                        MapCircle(center: center, radius: radiusMeters)
                            .stroke(notamStrokeColor(for: notam).opacity(model.effectiveOpacity(for: .notam)), style: notamStrokeStyle(for: notam))
                            .foregroundStyle(notamStrokeColor(for: notam).opacity(0.12 * model.effectiveOpacity(for: .notam)))
                        if model.shouldShowLayerLabels(for: .notam) {
                            Annotation(notam.reference, coordinate: center, anchor: .center) {
                                NOTAMMarker(notam: notam)
                                    .opacity(model.effectiveOpacity(for: .notam))
                            }
                        }
                    case let .polygon(coordinates):
                        MapPolygon(coordinates: coordinates)
                            .stroke(notamStrokeColor(for: notam).opacity(model.effectiveOpacity(for: .notam)), style: notamStrokeStyle(for: notam))
                            .foregroundStyle(notamStrokeColor(for: notam).opacity(0.12 * model.effectiveOpacity(for: .notam)))
                        if model.shouldShowLayerLabels(for: .notam), let labelCoordinate = coordinates.first {
                            Annotation(notam.reference, coordinate: labelCoordinate, anchor: .center) {
                                NOTAMMarker(notam: notam)
                                    .opacity(model.effectiveOpacity(for: .notam))
                            }
                        }
                    case nil:
                        EmptyMapContent()
                    }
                }
            }
        }
    }

    private func warningBanner(text: String, tint: Color = .red) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(text)
                .font(.headline)
            Spacer()
        }
        .padding(16)
        .background(tint.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .foregroundStyle(.white)
    }

    private func warningRow(text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline)
        }
        .padding(10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func aircraftRow(for aircraft: AircraftPresentation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(aircraft.displayName)
                    .font(.headline)
                Spacer()
                Text(aircraft.sourceLabel)
                    .foregroundStyle(.secondary)
            }

            Text("\(aircraft.distanceKilometers, specifier: "%.2f") km • \(Int(aircraft.relativeAltitudeFeet)) ft AGL • \(Int(aircraft.speedKnots)) kt • \(Int(aircraft.heading))°")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(aircraft.isAlerting ? .red : .secondary)
            Text(aircraft.relativeBearingSummary)
                .font(.caption)
                .foregroundStyle(aircraft.isAhead ? .primary : .secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(aircraft.isAlerting ? 0.9 : 0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func alertRow(for aircraft: AircraftPresentation) -> some View {
        HStack {
            Image(systemName: "airplane.circle.fill")
                .foregroundStyle(aircraft.urgencyScore >= 0.8 ? .red : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(aircraft.displayName)
                    .fontWeight(.semibold)
                Text("\(aircraft.relativeBearingSummary) • \(aircraft.isApproaching ? "Approaching" : "Steady") • \(aircraft.isDescending ? "Descending" : "Level")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(aircraft.distanceKilometers, specifier: "%.2f") km / \(Int(aircraft.relativeAltitudeFeet)) ft")
                .font(.subheadline.monospacedDigit())
        }
        .padding(12)
        .background((aircraft.urgencyScore >= 0.8 ? Color.red : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func windFloatingPanel(_ wind: WindEstimate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "location.north.fill")
                .rotationEffect(.degrees(wind.directionDegrees))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated wind (weather data)")
                    .font(.caption.weight(.semibold))
                Text("\(formatted(wind.speedKilometersPerHour, decimals: 0)) km/h  •  Gust \(formatted(wind.gustKilometersPerHour ?? wind.speedKilometersPerHour, decimals: 0))  •  \(formatted(wind.directionDegrees, decimals: 0))° \(wind.directionCompass)")
                    .font(.caption2.monospacedDigit())
            }

            Spacer()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func weatherFloatingPanel(_ weather: AtmosphericCondition) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cloud.sun.fill")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Weather data is estimated from nearby stations/models")
                    .font(.caption.weight(.semibold))
                Text(weatherOverlaySummary(weather))
                    .font(.caption2.monospacedDigit())
            }

            Spacer()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func notamSummaryRow(_ notam: StructuredNOTAM) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(notam.reference)
                    .font(.headline)
                Spacer()
                Text(notam.kind.label)
                    .foregroundStyle(.secondary)
            }
            Text(notam.altitudeBand.label)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            if let from = notam.validFrom, let until = notam.validUntil {
                Text("\(from.formatted(date: .abbreviated, time: .shortened)) → \(until.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(notam.summary.isEmpty ? notam.originalText : notam.summary)
                .font(.caption)
                .lineLimit(3)
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatted(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }

    private func powerLineColor(for line: PowerLineFeature) -> Color {
        switch line.category {
        case .transmission:
            .red
        case .distribution:
            .orange
        }
    }

    private func powerBufferColor(for line: PowerLineFeature) -> Color {
        switch line.category {
        case .transmission:
            .red
        case .distribution:
            .yellow
        }
    }

    private var bufferLineWidth: CGFloat {
        max(10, CGFloat(model.powerBufferMeters / 2.5))
    }

    private func weatherOverlaySummary(_ weather: AtmosphericCondition) -> String {
        let temp = weather.temperatureCelsius.map { "\(formatted($0, decimals: 1))°C" } ?? "--"
        let precip = weather.precipitationMillimeters.map { "\(formatted($0, decimals: 1)) mm" } ?? "--"
        let cloud = weather.cloudCoverPercent.map { "\(formatted($0, decimals: 0))%" } ?? "--"
        return "\(temp)  •  Rain \(precip)  •  Cloud \(cloud)"
    }

    private func notamStrokeColor(for notam: StructuredNOTAM) -> Color {
        if notam.isUpcoming {
            return .purple.opacity(0.75)
        }
        return .purple
    }

    private func notamStrokeStyle(for notam: StructuredNOTAM) -> StrokeStyle {
        if notam.isUpcoming {
            return StrokeStyle(lineWidth: 2, dash: [8, 6])
        }
        return StrokeStyle(lineWidth: 2)
    }
}

private struct AircraftAnnotationView: View {
    let aircraft: AircraftPresentation

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: aircraft.isAlerting ? "airplane.circle.fill" : "airplane.circle")
                .font(.title2)
                .rotationEffect(.degrees(aircraft.heading))
                .foregroundStyle(aircraft.isAlerting ? .red : .blue)

            VStack(spacing: 2) {
                Text(aircraft.displayName)
                    .font(.caption.weight(.semibold))
                Text("\(Int(aircraft.relativeAltitudeFeet)) ft • \(aircraft.distanceKilometers, specifier: "%.1f") km")
                    .font(.caption2.monospacedDigit())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .opacity(aircraft.isEmphasized ? 1 : 0.48)
    }
}

private struct WindDirectionMarker: View {
    let wind: WindEstimate

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "location.north.fill")
                .font(.title)
                .rotationEffect(.degrees(wind.directionDegrees))
                .foregroundStyle(.cyan)

            Text("\(Int(wind.speedKilometersPerHour)) km/h")
                .font(.caption2.monospacedDigit())
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

private struct PowerStructureMarker: View {
    let structure: PowerStructure

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: structure.kind == "pole" ? "mappin.circle" : "bolt.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            Text(structure.kind.capitalized)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

private struct CompassRoseView: View {
    let headingDegrees: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .stroke(.white.opacity(0.5), lineWidth: 1)
            ForEach(["N", "E", "S", "W"], id: \.self) { point in
                Text(point)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(point == "N" ? .red : .primary)
                    .offset(labelOffset(for: point))
            }
            Image(systemName: "location.north.fill")
                .font(.title3)
                .foregroundStyle(.cyan)
                .rotationEffect(.degrees(headingDegrees))
        }
        .frame(width: 56, height: 56)
    }

    private func labelOffset(for point: String) -> CGSize {
        switch point {
        case "N":
            CGSize(width: 0, height: -20)
        case "E":
            CGSize(width: 20, height: 0)
        case "S":
            CGSize(width: 0, height: 20)
        default:
            CGSize(width: -20, height: 0)
        }
    }
}

private struct HeadingIndicatorView: View {
    let headingDegrees: Double

    var body: some View {
        Image(systemName: "location.north.line.fill")
            .font(.title2)
            .foregroundStyle(.cyan)
            .padding(8)
            .background(.thinMaterial, in: Circle())
            .rotationEffect(.degrees(headingDegrees))
    }
}

private struct FireDetectionMarker: View {
    let detection: FireDetection
    let showDetails: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "flame.circle.fill")
                .font(.title3)
                .foregroundStyle(color)

            if showDetails {
                VStack(spacing: 2) {
                    Text(detection.source)
                        .font(.caption2.weight(.semibold))
                    Text(detailLine)
                        .font(.caption2.monospacedDigit())
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var color: Color {
        switch detection.confidence {
        case .low:
            .yellow
        case .medium:
            .orange
        case .high:
            .red
        }
    }

    private var detailLine: String {
        let date = detection.detectedAt.formatted(date: .omitted, time: .shortened)
        if let brightness = detection.brightness {
            return "\(date) • \(Int(brightness)) K"
        }
        return date
    }
}

private struct WeatherOverlayMarker: View {
    let weather: AtmosphericCondition

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "cloud.sun.fill")
                .font(.title3)
                .foregroundStyle(.blue)
            Text(label)
                .font(.caption2.monospacedDigit())
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var label: String {
        let temp = weather.temperatureCelsius.map { "\(Int($0))°C" } ?? "--"
        let cloud = weather.cloudCoverPercent.map { "\(Int($0))%" } ?? "--"
        return "\(temp) / \(cloud)"
    }
}

private struct NOTAMMarker: View {
    let notam: StructuredNOTAM

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.title3)
                .foregroundStyle(notam.isUpcoming ? .purple.opacity(0.7) : .purple)
            Text("\(notam.kind.label) • \(notam.altitudeBand.label)")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

#Preview {
    ContentView(model: .preview)
}
