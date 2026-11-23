import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';

/// OpenStreetMap raster tiles.
///
/// Keyless and free, which is why the app uses them instead of Google Maps.
/// The package name is sent as required by the OSM tile usage policy.
class OsmTileLayer extends StatelessWidget {
  const OsmTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.hamrofutsal.futsal_lead',
      maxNativeZoom: 19,
    );
  }
}

/// The attribution OSM requires whenever its tiles are shown.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: Colors.white70,
        child: Text(
          compact ? '© OpenStreetMap' : '© OpenStreetMap contributors',
          style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// A small, non-interactive map showing one pinned point.
///
/// Used as a confirmation thumbnail on forms and detail screens: seeing the
/// pin in the right neighbourhood catches a mistyped coordinate instantly,
/// which two decimal numbers never do.
class MapPreview extends StatelessWidget {
  const MapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 150,
    this.zoom = 15,
    this.onTap,
  });

  final double latitude;
  final double longitude;
  final double height;
  final double zoom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              // Rebuilt whenever the point changes so the preview follows the
              // coordinate fields.
              key: ValueKey('$latitude,$longitude'),
              options: MapOptions(
                initialCenter: point,
                initialZoom: zoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                const OsmTileLayer(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const OsmAttribution(compact: true),
              ],
            ),
            if (onTap != null)
              Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
          ],
        ),
      ),
    );
  }
}
