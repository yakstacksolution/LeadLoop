import 'package:geolocator/geolocator.dart';

/// The outcome of asking the device where it is.
sealed class LocationOutcome {
  const LocationOutcome();
}

/// Coordinates were obtained with the user's consent.
class LocationFixed extends LocationOutcome {
  const LocationFixed({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final double latitude;
  final double longitude;

  /// Radius of uncertainty in metres, as reported by the platform.
  final double accuracy;
}

/// No coordinates. [reason] is shown to the user so they understand why the
/// visit will be recorded as self-reported rather than location-supported.
class LocationUnavailable extends LocationOutcome {
  const LocationUnavailable(this.reason, {this.isPermanentlyDenied = false});

  final String reason;
  final bool isPermanentlyDenied;
}

/// Wraps the one-shot location request used when starting a venue visit.
///
/// There is no background or continuous tracking anywhere in this app: a fix
/// is requested only at the moment an employee taps "Start visit", and a
/// refusal is a supported outcome, never a blocker.
class LocationService {
  const LocationService();

  /// Requests a single position, asking for permission if needed.
  ///
  /// Never throws — every failure path returns [LocationUnavailable] so the
  /// visit can still be recorded without coordinates.
  Future<LocationOutcome> getCurrentPosition({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationUnavailable(
          'Location services are turned off on this device.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationUnavailable(
          'Location permission is permanently denied. You can enable it in '
          'your device settings.',
          isPermanentlyDenied: true,
        );
      }
      if (permission == LocationPermission.denied) {
        return const LocationUnavailable('Location permission was not granted.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      return LocationFixed(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (error) {
      return LocationUnavailable('Could not get a location fix: $error');
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
