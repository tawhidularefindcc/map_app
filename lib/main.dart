import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Google Maps Demo',
      home: MapSample(),
    );
  }
}

class MapSample extends StatefulWidget {
  const MapSample({Key? key}) : super(key: key);

  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
  final Completer<GoogleMapController> _controller = Completer();

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(17.385044, 78.486671),
    zoom: 18,
  );

  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  late MarkerId markerId1;
  late Marker marker1;
  final Location _locationService = Location();
  LocationData? initialLocation;
  LocationData? _currentLocation;
  late MapType maptype;
  bool updateStarted = false;

  late StreamSubscription<LocationData> _locationSubscription;
  PermissionStatus? _permissionGranted;
  String error = "";
  @override
  void initState() {
    super.initState();
    maptype = MapType.normal;
    markerId1 = const MarkerId("Current");
    marker1 = Marker(
        markerId: markerId1,
        position: const LatLng(17.385044, 78.486671),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
            title: "Hytech City", onTap: () {}, snippet: "Snipet Hitech City"));
    markers[markerId1] = marker1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
        title: const Text(
          "Flutter Track Location",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (builder) {
              return <PopupMenuEntry<int>>[
                const PopupMenuItem<int>(
                  value: 0,
                  child: Text('Hybrid'),
                ),
                const PopupMenuItem<int>(
                  value: 1,
                  child: Text('Normal'),
                ),
                const PopupMenuItem<int>(
                  value: 2,
                  child: Text('Satellite'),
                ),
                const PopupMenuItem<int>(
                  value: 3,
                  child: Text('Terrain'),
                ),
              ];
            },
            onSelected: (value) {
              switch (value) {
                case 0:
                  setState(() {
                    maptype = MapType.hybrid;
                  });
                  break;
                case 1:
                  setState(() {
                    maptype = MapType.normal;
                  });
                  break;
                case 2:
                  setState(() {
                    maptype = MapType.satellite;
                  });
                  break;
                case 3:
                  setState(() {
                    maptype = MapType.terrain;
                  });
                  break;
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Stack(
          children: [
            GoogleMap(
              mapType: maptype,
              initialCameraPosition: _kGooglePlex,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              markers: Set<Marker>.of(markers.values),
            ),
            Align(
                alignment: Alignment.topCenter,
                child: Container(
                  color: Colors.white60,
                  child: Text(
                    _currentLocation != null
                        ? 'Current location: \nlat: ${_currentLocation!.latitude}\n  long: ${_currentLocation!.longitude} '
                        : 'Error: $error\n',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.pink, fontSize: 20),
                  ),
                ))
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: !updateStarted ? Colors.blue : Colors.red,
        onPressed: !updateStarted ? _startTrack : _stopTrack,
        label: Text(!updateStarted ? 'Start Track!' : 'Stop Track'),
        icon: const Icon(
          Icons.directions_boat,
        ),
      ),
    );
  }

  initPlatformState() async {
    await _locationService.changeSettings(
        accuracy: LocationAccuracy.high, interval: 1000);

    LocationData? locationData;
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (serviceEnabled) {
        _permissionGranted = (await _locationService.requestPermission());
        if (_permissionGranted!.index == 0) {
          locationData = await _locationService.getLocation();
          enableLocationSubscription();
        }
      } else {
        bool serviceRequestGranted = await _locationService.requestService();
        if (serviceRequestGranted) {
          initPlatformState();
        }
      }
    } on PlatformException catch (e) {
      log(e.toString());
      if (e.code == 'PERMISSION_DENIED') {
        error = e.message!;
      } else if (e.code == 'SERVICE_STATUS_ERROR') {
        error = e.message!;
      }
      //locationData = null;
    }

    setState(() {
      initialLocation = locationData!;
    });
  }

  enableLocationSubscription() async {
    _locationSubscription =
        _locationService.onLocationChanged.listen((LocationData result) async {
      if (mounted) {
        setState(() {
          _currentLocation = result;

          markers.clear();
          MarkerId markerId1 = const MarkerId("Current");
          Marker marker1 = Marker(
            markerId: markerId1,
            position: const LatLng(17.385044, 78.486671),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          );
          markers[markerId1] = marker1;
          animateCamera(marker1);
        });
      }
    });
  }

  slowRefresh() async {
    _locationSubscription.cancel();
    await _locationService.changeSettings(
        accuracy: LocationAccuracy.balanced, interval: 10000);
    enableLocationSubscription();
  }

  Future<void> _startTrack() async {
    initPlatformState();
    setState(() {
      updateStarted = true;
    });
  }

  Future<void> _stopTrack() async {
    if (_locationSubscription != null) _locationSubscription.cancel();

    setState(() {
      updateStarted = false;
    });
  }

  animateCamera(marker1) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(marker1));
  }
}
