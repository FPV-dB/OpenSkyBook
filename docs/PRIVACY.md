# OpenSkyBook Privacy Notes

OpenSkyBook is a native macOS app for local planning and situational awareness. Some workflows may use location, map, weather, NOTAM, fire, or infrastructure data depending on configuration.

## Local Data

OpenSkyBook may store app preferences locally, including:

- Location source preference.
- Manual coordinates.
- Layer visibility and opacity choices.
- Alert settings.
- Safety weighting preferences.
- Disclaimer acknowledgment.

## Location Data

The app can use device GPS/location data through macOS location services. macOS controls the permission prompt.

Manual coordinates are available when you do not want to use device location.

## Network Requests

Depending on enabled features and configuration, OpenSkyBook may make network requests for:

- Map imagery or map services.
- Weather and wind estimates.
- NOTAM briefing text from a configured URL.
- Power infrastructure datasets.
- NASA FIRMS fire detections when configured.
- Aircraft/network feed data when configured.

## API Keys And Environment Configuration

Some optional providers require local configuration, such as:

- `FIRMS_MAP_KEY` for NASA FIRMS fire detection.
- `AIRSERVICES_NOTAM_TEXT_URL` for automated NOTAM text retrieval.
- Power dataset environment values such as `SAPN_POWER_DATA_URL` or custom dataset definitions.

Do not commit private API keys, feed URLs, or operational credentials to the repository.

## Screenshots

Repository screenshots are redacted documentation assets. They use representative sample data and do not expose live user location, private feed credentials, or real operational field notes.

## No Analytics Claim

OpenSkyBook does not intentionally include analytics or advertising code in the current app source. Review configured providers before enabling network-backed workflows.

## Third-Party Sources

When a configured provider is used, that provider's terms and privacy practices may apply. Review provider policies before using private locations or operational data with external services.
