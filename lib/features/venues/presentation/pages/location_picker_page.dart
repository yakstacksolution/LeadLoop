import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/place_search_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/map_tiles.dart';

/// What the picker hands back to the form.
class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;

  /// Best-effort label for the point, used to offer filling the address field.
  final String? address;
}

/// Full-screen map for choosing a venue's coordinates.
///
/// Three ways in, because field staff arrive with different information:
/// search by name, drop the pin by moving the map, or take the device's own
/// fix when standing at the venue.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialQuery,
  });

  final double? initialLatitude;
  final double? initialLongitude;

  /// Seeds the search box, e.g. with the venue name already typed in the form.
  final String? initialQuery;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  /// Kathmandu. Used only when the venue has no coordinates yet and the
  /// device fix has not arrived — the map must open somewhere.
  static const _fallbackCentre = LatLng(27.7172, 85.3240);

  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _placeSearch = sl<PlaceSearchService>();

  Timer? _debounce;
  List<PlaceResult> _results = const [];
  bool _searching = false;
  bool _locating = false;

  /// Notifiers rather than setState: they change on every frame of a pan, and
  /// only the confirm bar shows them.
  late final _centre = ValueNotifier<LatLng>(
    widget.initialLatitude != null && widget.initialLongitude != null
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : _fallbackCentre,
  );

  final _address = ValueNotifier<String?>(null);
  final _resolvingAddress = ValueNotifier(false);

  /// Bumped when the pin moves or the query changes, so a slow response for
  /// an earlier one is ignored.
  int _reverseRun = 0;
  int _searchRun = 0;

  /// Reverse-geocode runs are throttled: the map fires position updates on
  /// every frame of a pan, and Nominatim would rate-limit us.
  Timer? _reverseDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery ?? '';
    if (widget.initialLatitude != null) _scheduleReverse(_centre.value);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _reverseDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    _centre.dispose();
    _address.dispose();
    _resolvingAddress.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _searchRun++;
    if (value.trim().length < 3) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _debounce = Timer(
      PlaceSearchService.searchDebounce,
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String query) async {
    final run = _searchRun;
    final results = await _placeSearch.search(query);
    if (!mounted || run != _searchRun) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _selectResult(PlaceResult result) {
    final point = LatLng(result.latitude, result.longitude);
    _searchFocus.unfocus();
    _debounce?.cancel();
    _searchRun++;
    setState(() {
      _results = const [];
      _searching = false;
    });
    _centre.value = point;
    _address.value = result.fullAddress;
    _resolvingAddress.value = false;
    _reverseDebounce?.cancel();
    _reverseRun++;
    _mapController.move(point, 16);
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _centre.value = camera.center;
    _scheduleReverse(camera.center);
  }

  void _scheduleReverse(LatLng point) {
    _reverseDebounce?.cancel();
    _resolvingAddress.value = true;
    final run = ++_reverseRun;
    _reverseDebounce = Timer(const Duration(milliseconds: 700), () async {
      final result = await _placeSearch.reverse(
        point.latitude,
        point.longitude,
      );
      if (!mounted || run != _reverseRun) return;
      _address.value = result?.fullAddress;
      _resolvingAddress.value = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final outcome = await sl<LocationService>().getCurrentPosition();
    if (!mounted) return;
    setState(() => _locating = false);

    switch (outcome) {
      case LocationFixed(:final latitude, :final longitude):
        final point = LatLng(latitude, longitude);
        _centre.value = point;
        _mapController.move(point, 17);
        _scheduleReverse(point);
      case LocationUnavailable(:final reason):
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(reason)));
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      PickedLocation(
        latitude: _centre.value.latitude,
        longitude: _centre.value.longitude,
        address: _address.value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showResults =
        _searchFocus.hasFocus && (_results.isNotEmpty || _searching);

    return Scaffold(
      appBar: AppBar(title: const Text('Pick location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centre.value,
              initialZoom: widget.initialLatitude == null ? 12 : 16,
              minZoom: 3,
              maxZoom: 18,
              onPositionChanged: _onMapMoved,
              onTap: (_, point) {
                _searchFocus.unfocus();
                _centre.value = point;
                _mapController.move(point, _mapController.camera.zoom);
                _scheduleReverse(point);
              },
            ),
            children: const [OsmTileLayer(), OsmAttribution()],
          ),

          // The pin sits at the centre of the viewport rather than on the map,
          // so panning the map under it reads as dragging the pin — steadier
          // than a draggable marker under a thumb.
          IgnorePointer(
            child: Center(
              child: Padding(
                // Lift it so the point of the pin, not its middle, marks the
                // centre.
                padding: const EdgeInsets.only(bottom: 34),
                child: _CentrePin(),
              ),
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: _SearchBar(
              controller: _searchController,
              focusNode: _searchFocus,
              searching: _searching,
              onChanged: _onQueryChanged,
              onClear: () {
                _searchController.clear();
                _onQueryChanged('');
              },
              results: showResults ? _results : const [],
              onResultTap: _selectResult,
            ),
          ),

          Positioned(
            right: 12,
            bottom: 172,
            child: _MapButton(
              icon: Icons.my_location,
              busy: _locating,
              tooltip: 'Use my current location',
              onTap: _locating ? null : _useCurrentLocation,
            ),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([_centre, _address, _resolvingAddress]),
        builder: (context, _) => _ConfirmBar(
          centre: _centre.value,
          address: _address.value,
          resolving: _resolvingAddress.value,
          onConfirm: _confirm,
        ),
      ),
    );
  }
}

class _CentrePin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_on, size: 46, color: AppColors.primary),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onChanged,
    required this.onClear,
    required this.results,
    required this.onResultTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final List<PlaceResult> results;
  final ValueChanged<PlaceResult> onResultTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surface,
          elevation: 3,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: onChanged,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search a place, e.g. Kirtipur Futsal',
                    ),
                  ),
                ),
                if (searching)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClear,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Clear',
                  ),
              ],
            ),
          ),
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 6),
          Material(
            color: AppColors.surface,
            elevation: 3,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 268),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: results.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.outline),
                itemBuilder: (context, index) {
                  final result = results[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.place_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: result.subtitle.isEmpty
                        ? null
                        : Text(
                            result.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                    onTap: () => onResultTap(result),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            height: 46,
            width: 46,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Icon(icon, size: 21, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.centre,
    required this.address,
    required this.resolving,
    required this.onConfirm,
  });

  final LatLng centre;
  final String? address;
  final bool resolving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resolving
                              ? 'Finding address…'
                              : address ?? 'Dropped pin',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${centre.latitude.toStringAsFixed(6)}, '
                          '${centre.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check),
                label: const Text('Use this location'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
