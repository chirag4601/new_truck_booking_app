import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoder/geocoder.dart';
import 'package:location_permissions/location_permissions.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:Liveasy/widgets/backend_connection.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:Liveasy/widgets/providerData.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
String mapKey = "AIzaSyCTVVijIWofDrI6LpSzhUqJIF90X-iyZmE";

Future<GpsDataModel> getGpsDataFromApi(int imei)async{
    sleep(Duration(seconds: 20));
    var jsonData;
    http.Response response;
    response =
    await http.get("http://65.2.59.24:3000/locationbyimei/${imei.toString()}");
    jsonData = await jsonDecode(response.body);
    print("API started");
    print(response.statusCode);
    print(jsonData);
    GpsDataModel gpsDataModel = new GpsDataModel();
    gpsDataModel.imei = jsonData["imei"];
    gpsDataModel.lat = double.parse(jsonData["lat"]);
    gpsDataModel.lng = double.parse(jsonData["lng"]);
    gpsDataModel.speed = jsonData["speed"];
    gpsDataModel.deviceName = jsonData["deviceName"];
    gpsDataModel.powerValue = jsonData["powerValue"];
    return gpsDataModel;
}

class ShowMapWithImei extends StatefulWidget {
  GpsDataModel gpsData;
  Position userLocation;
  ShowMapWithImei({this.gpsData, this.userLocation});
  @override
  _ShowMapWithImeiState createState() => _ShowMapWithImeiState();
}

class _ShowMapWithImeiState extends State<ShowMapWithImei> {
  @override
  void initState() {
    super.initState();
     getAddress();
     setCustomMapPin("assets/truckAsMarker.jpeg");
  }
  @override
  void dispose() {
    super.dispose();
    shouldRun = false;
  }

  bool shouldRun = true;
  void getGpsDataByImei({String imei}) async {
    while(shouldRun){
    final GpsDataModel result = await compute( getGpsDataFromApi, int.parse(Provider.of<NewDataByShipper>(context, listen: false).gpsData.imei) );
    Provider.of<NewDataByShipper>(context, listen: false).updateGpsData(result);
    getAddress();
    updateDeviceMarker(LatLng(Provider.of<NewDataByShipper>(context,listen: false).gpsData.lat, Provider.of<NewDataByShipper>(context,listen: false).gpsData.lng));
    }
  }
  String address = "";
  BitmapDescriptor pinLocationIcon;
  Map<PolylineId, Polyline> polylines = {};
  Set<Marker> markers = {};
  Position myLocation;
  String mapMyIndiaToken = "";
  Completer<GoogleMapController> _controllerGoogleMap = Completer();
  GoogleMapController googleMapController;
  CameraPosition _initialCameraPosition = CameraPosition(target: LatLng(27,77), zoom: 14,);



  void updateDeviceMarker(LatLng latLng ) async{
    setState(() {
      markers.add(
          Marker(
              markerId: MarkerId("DeviceMarker"),
              position: latLng,
              icon: pinLocationIcon));
       _createPolylines(myLocation, Position(latitude: latLng.latitude, longitude: latLng.longitude));
    });
  }

  void setCustomMapPin(String imageLocation) async {
    pinLocationIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5),
        '$imageLocation');
  }

  Future<String> getMapMyIndiaToken()async{
    http.Response tokenGet = await http.post('https://outpost.mapmyindia.com/api/security/oauth/token?grant_type=client_credentials&client_id=33OkryzDZsJmp0siGnK04TeuQrg3DWRxswnTg_VBiHew-2D1tA3oa3fthrGnx4vwbwlbF_xT2T4P9dykuS1GUNmbRb8e5CUgz-RgWDyQspeDCXkXK5Nagw==&client_secret=lrFxI-iSEg9xHXNZXiqUoprc9ZvWP_PDWBDw94qhrze0sUkn7LBDwRNFscpDTVFH7aQT4tu6ycN0492wqPs-ewpjObJ6xuR7iRufmSVcnt9fys5dp0F5jlHLxBEj7oqq');
    print(tokenGet.statusCode);
    print(tokenGet.body);
    var body = jsonDecode(tokenGet.body);
    String token = body["access_token"];
    return token;
  }

  void getAddress()async{
    var addresses = await Geocoder.local.findAddressesFromCoordinates(Coordinates(Provider.of<NewDataByShipper>(context,listen: false).gpsData.lat, Provider.of<NewDataByShipper>(context,listen: false).gpsData.lng));
    var first = addresses.first;
    print(first.addressLine);
    if(mapMyIndiaToken == ""){
      mapMyIndiaToken = await getMapMyIndiaToken();
    }
    // used geocoding (instead of directly getting address using lat,lng) bcs rev-geocoding has a limit of 200 and geocoding has 5000 limit per day
    http.Response response = await http.get('https://atlas.mapmyindia.com/api/places/geocode?address=${first.addressLine}',
      headers: {HttpHeaders.authorizationHeader: "$mapMyIndiaToken"},);
    print(response.statusCode);
    var adress = jsonDecode(response.body);
    print(adress);
    var street = adress["copResults"]["street"] == null || adress["copResults"]["street"] == ""  ? "": "${adress["copResults"]["street"]}, ";
    var locality = adress["copResults"]["locality"] == null || adress["copResults"]["locality"] == "" ? "": "${adress["copResults"]["locality"]}, ";
    var cityName = adress["copResults"]["city"];
    var stateName = adress["copResults"]["state"];
    setState(() {
      address = "$street$locality$cityName, $stateName";
    });
  }

  _createPolylines(Position start, Position destination) async {
    PolylinePoints polylinePoints = PolylinePoints();
    List<LatLng> polylineCoordinates = [];
    // PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
    //   mapKey, // Google Maps API Key
    //   PointLatLng(start.latitude, start.longitude),
    //   PointLatLng(destination.latitude, destination.longitude),
    //   travelMode: TravelMode.transit,
    // );
    // print(result.status);
    // print(result.errorMessage);
    // print(result.points);
    http.Response response= await http.get('https://apis.mapmyindia.com/advancedmaps/v1/5ug2mtejb2urr2zwgdg8l8mh3zdtm2i3/route_adv/driving/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}');
    var body = jsonDecode(response.body);
    List<PointLatLng> polylinePoint = polylinePoints.decodePolyline(body["routes"][0]["geometry"]);
    String distanceBetween = body["routes"][0]["distance"].toString();
    print(distanceBetween);
    print(polylinePoint);
    // Adding the coordinates to the list
    if (polylinePoint.length != 0) {
      polylinePoint.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }
    PolylineId id = PolylineId('poly');
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.blue,
      points: polylineCoordinates,
      width: 5,
    );
    setState(() {
      polylines[id] = polyline;
    });
  }

  void showMarkerAtPosition(Position position, String markerID, BitmapDescriptor bitmapDescriptor)async{
    Marker newMarker = Marker(
      icon:  bitmapDescriptor,
      markerId: MarkerId(markerID),
      position: LatLng(
        position.latitude,
        position.longitude,
      ),
    );
    setState(() {
      markers.add(newMarker);
    });
  }

  void getCurrentLocation() async {
    PermissionStatus permission1 =
    await LocationPermissions().checkPermissionStatus();
    while (permission1 != PermissionStatus.granted){
      permission1 = await LocationPermissions().requestPermissions();
    }
    Position position;
    if (widget.userLocation == null) {
      position = await Geolocator().getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation);}
    else{position = widget.userLocation;}
    LatLng coordinates = LatLng(position.latitude, position.longitude);
    print(coordinates);
    myLocation = Position(latitude:position.latitude, longitude: position.longitude);
    // CameraPosition cameraPosition = CameraPosition(target: coordinates, zoom: 19);
    //  googleMapController.animateCamera(CameraUpdate.newCameraPosition(cameraPosition),);//camera moved to user's position
    // http.Response response = await http.get('http://apis.mapmyindia.com/advancedmaps/v1/5ug2mtejb2urr2zwgdg8l8mh3zdtm2i3/rev_geocode?lat=${position.latitude}&lng=${position.longitude}');
    // var body = jsonDecode(response.body);//gives address
    // print(body["results"][0]["locality"]);
    // print(body["results"][0]);
    LatLng latLng_1 = coordinates;
    LatLng latLng_2 = LatLng(Provider.of<NewDataByShipper>(context,listen: false).gpsData.lat, Provider.of<NewDataByShipper>(context,listen: false).gpsData.lng);
    if (latLng_1.latitude > latLng_2.latitude){
      latLng_1 = LatLng(Provider.of<NewDataByShipper>(context,listen: false).gpsData.lat, Provider.of<NewDataByShipper>(context,listen: false).gpsData.lng);
      latLng_2 = coordinates;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: latLng_1,
      northeast: latLng_1,
    );
// calculating centre of the bounds
    LatLng centerBounds = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude)/2,
        (bounds.northeast.longitude + bounds.southwest.longitude)/2
    );

// setting map position to centre to start with
    googleMapController.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: centerBounds,
      zoom: 18,
    )));
    zoomToFit(googleMapController, bounds, centerBounds);

    // LatLngBounds bound = LatLngBounds(southwest: latLng_1, northeast: latLng_2);
    // print(bound);
    // CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bound, 50);
    //  googleMapController.animateCamera(cameraUpdate);


    showMarkerAtPosition(myLocation, "myPosition", BitmapDescriptor.defaultMarker);
    updateDeviceMarker(LatLng(Provider.of<NewDataByShipper>(context,listen: false).gpsData.lat, Provider.of<NewDataByShipper>(context,listen: false).gpsData.lng));
    getGpsDataByImei(imei: "355172100788965");
  }


  Future<void> zoomToFit(GoogleMapController controller, LatLngBounds bounds, LatLng centerBounds) async {
    bool keepZoomingOut = true;

    while(keepZoomingOut) {
      final LatLngBounds screenBounds = await controller.getVisibleRegion();
      if(fits(bounds, screenBounds)){
        keepZoomingOut = false;
        final double zoomLevel = await controller.getZoomLevel() - 0.5;
        controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: centerBounds,
          zoom: zoomLevel,
        )));
        break;
      }
      else {
        // Zooming out by 0.1 zoom level per iteration
        final double zoomLevel = await controller.getZoomLevel() - 0.1;
        controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: centerBounds,
          zoom: zoomLevel,
        )));
      }
    }
  }
  bool fits(LatLngBounds fitBounds, LatLngBounds screenBounds) {
    final bool northEastLatitudeCheck = screenBounds.northeast.latitude >= fitBounds.northeast.latitude;
    final bool northEastLongitudeCheck = screenBounds.northeast.longitude >= fitBounds.northeast.longitude;

    final bool southWestLatitudeCheck = screenBounds.southwest.latitude <= fitBounds.southwest.latitude;
    final bool southWestLongitudeCheck = screenBounds.southwest.longitude <= fitBounds.southwest.longitude;

    return northEastLatitudeCheck && northEastLongitudeCheck && southWestLatitudeCheck && southWestLongitudeCheck;
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GestureDetector(
        onTap: (){FocusScope.of(context).unfocus();},
        child: Scaffold(
          body: SafeArea(
            child: Container(
              color: Color(0xFFF3F2F1),
              child: Column(mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        child: Row(
                          children: [
                            Container(
                              width : 250,
                              child: Text(address, style: TextStyle(fontSize: 18),),
                            ),
                            Text(Provider.of<NewDataByShipper>(context).gpsData.speed, style: TextStyle(fontSize: 50),),
                            Text("km/hr", style: TextStyle(fontSize: 13),)
                          ],
                        ),

                      ),
                    ],
                  ),
                  Expanded(
                    child: GoogleMap(
                       polylines: Set.from(polylines.values),
                      markers:  markers,
                      mapType: MapType.normal,
                      initialCameraPosition: _initialCameraPosition,
                      onMapCreated: (GoogleMapController controller){
                        _controllerGoogleMap.complete(controller);
                        googleMapController = controller;
                        googleMapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(Provider.of<NewDataByShipper>(context,listen: false).gpsData.lat, Provider.of<NewDataByShipper>(context,listen: false).gpsData.lng),zoom: 14.5)),);
                        getCurrentLocation();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

