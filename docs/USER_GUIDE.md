# OpenSkyBook User Guide

OpenSkyBook is a planning and situational-awareness surface for drone and FPV operations. It combines map context, advisory layers, aircraft awareness, weather/wind information, NOTAM review, and risk scoring.

## First Launch

1. Open `OpenSkyBook.app`.
2. Read and acknowledge the advisory disclaimer.
3. Choose a location source.
4. Select a data source mode.
5. Review filters, layers, safety status, and alert settings before relying on any view.

## Location

OpenSkyBook supports:

- **Device GPS**: uses macOS/CoreLocation where available.
- **Manual coordinates**: enter latitude and longitude directly.

Use manual coordinates when planning for a specific launch area, field site, or location where the Mac's current position is not the intended operating area.

## Source Mode

The Source section controls the preferred aircraft-awareness input:

- **Auto**: selects the best available source.
- **SDR**: local receiver-focused workflow.
- **Network**: network feed-focused workflow.
- **Combined**: combines context when available.

The active feed, health, and detail fields help explain what the app is currently using.

## Heading And Map Orientation

OpenSkyBook supports north-up and heading-up map workflows. Heading can come from compass data, GPS course, or a map-aligned fallback.

If heading is unavailable, use north-up mode and treat forward/path projections as advisory only.

## Filters

Filters control which traffic and advisories matter most for the current operation:

- Alert radius.
- Altitude threshold.
- Hide high-altitude traffic.
- Keep map centered on user.

Set these values conservatively for low-altitude drone and FPV work.

## Layers

The layer manager controls:

- Base map style.
- Presets.
- Startup mode.
- Clean mode.
- Quick opacity.
- Individual layer visibility, ordering, and opacity.

Supported advisory layers include:

- ADS-B traffic.
- Weather.
- Wind.
- Power infrastructure.
- Fire detection.
- NOTAM.

Use clean mode when you need a low-clutter map for visual review. Use preflight or emergency-style presets when you need more advisory context.

## Quick Layers

The quick layer panel provides fast map toggles for common overlays. Use it to temporarily show or hide layers without changing the full layer configuration.

## Wind And Weather

Wind and weather panels provide advisory estimates, including wind speed, gusts, direction, temperature, pressure, humidity, precipitation, cloud cover, and visibility when available.

Weather and wind values are model-derived or provider-derived. Verify critical decisions with official weather sources.

## NOTAM Review

OpenSkyBook supports manual NOTAM text parsing and configurable automated briefing sources.

Use NOTAM review to identify possible restrictions, temporary hazards, or relevant operational notes. Always verify NOTAM status with official sources before flight.

## Power Infrastructure

The power infrastructure layer can show powerlines, towers, poles, buffers, and projected path warnings.

Use this as an advisory obstacle-awareness layer. It may be incomplete or stale, especially where datasets are unavailable.

## Fire Detection

Fire detection can use NASA FIRMS data when configured with `FIRMS_MAP_KEY`. Detections may be delayed, incomplete, or affected by satellite overpass timing.

Always verify fire conditions through official emergency and local sources.

## Safety Panel

The Safety section summarizes:

- Overall risk band.
- Readiness text.
- Terrain, signal, RTH, light, and geofence advisory status.
- Checklist items.
- Prioritized alerts.
- Recent changes.
- Risk-factor breakdown.

The safety score is a decision-support aid. It is not an authorization to fly.

## Alerts

OpenSkyBook includes configurable audio and voice alerts for traffic and advisory layers.

Alert controls include:

- Alert mode.
- Sensitivity.
- Alert sound.
- Traffic radius.
- Traffic altitude.
- Alert volume.
- Approaching-only and descending-only criteria.

Treat alerts as reminders. They may miss hazards or warn late depending on source quality.

## Recommended Preflight Workflow

1. Set the intended operating location.
2. Confirm source health.
3. Set alert radius and altitude threshold.
4. Enable only relevant layers.
5. Review NOTAMs from official sources.
6. Review weather, wind, fire, and powerline advisories.
7. Review the Safety panel checklist.
8. Confirm local rules, permissions, airspace, and on-site conditions.

## Troubleshooting

### No traffic appears

Check the source mode, feed health, radius, altitude threshold, and source availability.

### Heading-up mode is disabled

The Mac may not have reliable heading data. Use north-up mode or move enough for GPS course to become meaningful.

### NOTAMs do not load automatically

Paste briefing text manually, or configure an automated source URL if supported in your environment.

### Fire detections do not appear

Set `FIRMS_MAP_KEY` and confirm the selected region has available detections.

### Power infrastructure is sparse

Configure an official dataset where possible. Fallback data may be incomplete.
