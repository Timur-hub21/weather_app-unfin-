import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as fio;
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_weather_app/models/forecast.dart';
import 'package:new_weather_app/models/weather.dart';
import 'package:path_provider/path_provider.dart';
import 'models/location.dart';
import 'package:new_weather_app/extensions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toast/toast.dart';

class CurrentWeatherPage extends StatefulWidget {
  final List<Location> locations;
  final BuildContext context;
  CurrentWeatherPage(this.locations, this.context, {Key? key});

  @override
  _CurrentWeatherPageState createState() => _CurrentWeatherPageState(locations);
}

class _CurrentWeatherPageState extends State<CurrentWeatherPage> {
  ConnectivityResult _connectivityResult = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _streamSubscription;
  final List<Location> locations;
  final Location location;
  Position? _currentPosition;
  String? _currentAddress;
  PermissionStatus? _status;
  late Box box;
  List data = [];

  Future openBox() async {
    var dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    box = await Hive.openBox('data');
    return;
  }

  Future<bool> getAllData(data) async {
    await openBox();
    String apiKey = "729b80b4f20cffdcb8afd03a35945d82";
    String city = location.city;
    String url =
        "https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric";

    try {
      var response = await http.get(Uri.parse(url));
      var _jsonDecode = jsonDecode(response.body);

      await putData(_jsonDecode);
    } catch (SocketException) {
      print('No internet connection');
    }

    var mymap = box.toMap().values.toList();
    if (mymap.isEmpty) {
      data.add('empty');
    } else {
      data = mymap;
    }
    return Future.value(true);
  }

  Future putData(data) async {
    await box.clear();
    for (var d in data) {
      box.add(d);
    }
  }

  Future<void> updateData() async {
    await openBox();
    String apiKey = "729b80b4f20cffdcb8afd03a35945d82";
    String city = location.city;
    String url =
        "https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric";

    try {
      var response = await http.get(Uri.parse(url));
      var _jsonDecode = jsonDecode(response.body);

      await putData(_jsonDecode);
    } catch (SocketException) {
      Toast.show('No Internet connection', context,
      duration: Toast.LENGTH_LONG, gravity: Toast.BOTTOM);
    }
  }

  Future<void> initConnectivity() async {
    late ConnectivityResult result;

    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      print(e.toString());
      return;
    }
    if (!mounted) {
      return Future.value(null);
    }
    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    setState(() {
      _connectivityResult = result;
    });
  }

  @override
  void initState() {
    super.initState();
    Permission.locationWhenInUse.status.then(_updateStatus);
    initConnectivity();

    _streamSubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _streamSubscription.cancel();
    super.dispose();
  }

  void _updateStatus(PermissionStatus status) {
    if (status != _status) {
      setState(() {
        _status = status;
      });
    }
  }

  void _askPermission() {
    [Permission.location, Permission.locationWhenInUse]
        .request()
        .then(_onStatusRequested);
  }

  void _onStatusRequested(Map<Permission, PermissionStatus> statuses) {
    final status = statuses[Permission.locationWhenInUse];
    if (status != PermissionStatus.granted) {
      openAppSettings();
    } else {
      _updateStatus(status!);
    }
  }

  _CurrentWeatherPageState(this.locations) : location = locations[0];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar:
          Text('Connection Status: ${_connectivityResult.toString()}'),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Weather App',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        actions: <Widget>[
          if (_currentAddress != null) Text(_currentAddress!),
          TextButton(
            child: Text("Get Location"),
            onPressed: () {
              _askPermission();
              _getCurrentLocation();
            },
          )
        ],
      ),
      backgroundColor: Colors.blue,
      body: ListView(
                    children: <Widget>[
                      currentWeatherViews(locations, location, context),
                      forcastViewsHourly(location),
                      forcastViewsDaily(location),
                    ],
                  ),
    );
  }

  _getCurrentLocation() {
    Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            forceAndroidLocationManager: true)
        .then((Position position) {
      setState(() {
        _currentPosition = position;
        getAddressFromLatLng();
      });
    }).catchError((e) {
      print(e);
    });
  }

  getAddressFromLatLng() async {
    try {
      List<fio.Placemark> placemarks = await fio.placemarkFromCoordinates(
          _currentPosition!.latitude, _currentPosition!.longitude);

      fio.Placemark place = placemarks[0];

      setState(() {
        _currentAddress =
            "${place.locality}, ${place.postalCode}, ${place.country}";
      });
    } catch (e) {
      print(e);
    }
  }
}

Widget currentWeatherViews(
    List<Location> locations, Location location, BuildContext context) {
  Weather? _weather;

  return FutureBuilder(
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        _weather = snapshot.data as Weather?;
        if (_weather == null) {
          return const Text("Error getting weather");
        } else {
          return Column(children: [
            createAppBar(locations, location, context),
            weatherBox(_weather!),
            weatherDetailsBox(_weather!),
          ]);
        }
      } else {
        return Center(child: CircularProgressIndicator());
      }
    },
    future: getCurrentWeather(location),
  );
}

Widget forcastViewsHourly(Location location) {
  Forecast? _forcast;

  return FutureBuilder(
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        _forcast = snapshot.data as Forecast?;
        if (_forcast == null) {
          return const Text("Error getting weather");
        } else {
          return hourlyBoxes(_forcast!);
        }
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    },
    future: getForecast(location),
  );
}

Widget forcastViewsDaily(Location location) {
  Forecast? _forcast;

  return FutureBuilder(
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        _forcast = snapshot.data as Forecast?;
        if (_forcast == null) {
          return const Text("Error getting weather");
        } else {
          return dailyBoxes(_forcast!);
        }
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    },
    future: getForecast(location),
  );
}

Widget createAppBar(
    List<Location> locations, Location location, BuildContext context) {
  return Container(
      padding: const EdgeInsets.only(left: 20, top: 15, bottom: 15, right: 20),
      margin:
          const EdgeInsets.only(top: 35, left: 15.0, bottom: 15.0, right: 15.0),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(60)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 5,
              blurRadius: 7,
              offset: const Offset(0, 3),
            )
          ]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: <TextSpan>[
                TextSpan(
                    text: '${location.city.capitalizeFirstOfEach}, ',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                TextSpan(
                    text: '${location.country.capitalizeFirstOfEach}',
                    style: const TextStyle(
                        fontWeight: FontWeight.normal, fontSize: 16)),
              ],
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.black,
            size: 24.0,
            semanticLabel: 'Tap to change location',
          ),
        ],
      ));
}

Widget weatherDetailsBox(Weather _weather) {
  return Container(
    padding: const EdgeInsets.only(left: 15, top: 25, bottom: 25, right: 15),
    margin: const EdgeInsets.only(left: 15, top: 5, bottom: 15, right: 15),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3),
          )
        ]),
    child: Row(
      children: [
        Expanded(
            child: Column(
          children: [
            const Text(
              "Wind",
              textAlign: TextAlign.left,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey),
            ),
            Text(
              "${_weather.wind} km/h",
              textAlign: TextAlign.left,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.black),
            )
          ],
        )),
        Expanded(
            child: Column(
          children: [
            const Text(
              "Humidity",
              textAlign: TextAlign.left,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey),
            ),
            Text(
              "${_weather.humidity.toInt()}%",
              textAlign: TextAlign.left,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.black),
            )
          ],
        )),
        Expanded(
            child: Column(
          children: [
            Container(
                child: Text(
              "Pressure",
              textAlign: TextAlign.left,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey),
            )),
            Container(
                child: Text(
              "${_weather.pressure} hPa",
              textAlign: TextAlign.left,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.black),
            ))
          ],
        ))
      ],
    ),
  );
}

Widget weatherBox(Weather _weather) {
  return Stack(children: [
    Container(
      padding: const EdgeInsets.all(15.0),
      margin: const EdgeInsets.all(15.0),
      height: 160.0,
      decoration: BoxDecoration(
          color: Colors.indigoAccent,
          borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
    ClipPath(
        clipper: Clipper(),
        child: Container(
            padding: const EdgeInsets.all(15.0),
            margin: const EdgeInsets.all(15.0),
            height: 160.0,
            decoration: BoxDecoration(
                color: Colors.indigoAccent[400],
                borderRadius: BorderRadius.all(Radius.circular(20))))),
    Container(
        padding: const EdgeInsets.all(15.0),
        margin: const EdgeInsets.all(15.0),
        height: 160.0,
        decoration:
            BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(20))),
        child: Row(
          children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                  getWeatherIcon(_weather.icon),
                  Container(
                      margin: const EdgeInsets.all(5.0),
                      child: Text(
                        "${_weather.description.capitalizeFirstOfEach}",
                        style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 16,
                            color: Colors.white),
                      )),
                  Container(
                      margin: const EdgeInsets.all(5.0),
                      child: Text(
                        "H:${_weather.high.toInt()}° L:${_weather.low.toInt()}°",
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 13,
                            color: Colors.white),
                      )),
                ])),
            Column(children: <Widget>[
              Container(
                  child: Text(
                "${_weather.temp.toInt()}°",
                textAlign: TextAlign.left,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 60,
                    color: Colors.white),
              )),
              Container(
                  margin: const EdgeInsets.all(0),
                  child: Text(
                    "Feels like ${_weather.feelsLike.toInt()}°",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 13,
                        color: Colors.white),
                  )),
            ])
          ],
        ))
  ]);
}

Image getWeatherIcon(String _icon) {
  String path = 'assets/icons/';
  String imageExtension = ".png";
  return Image.asset(
    path + _icon + imageExtension,
    width: 70,
    height: 70,
  );
}

Image getWeatherIconSmall(String _icon) {
  String path = 'assets/icons/';
  String imageExtension = ".png";
  return Image.asset(
    path + _icon + imageExtension,
    width: 40,
    height: 40,
  );
}

Widget hourlyBoxes(Forecast _forecast) {
  return Container(
      margin: EdgeInsets.symmetric(vertical: 0.0),
      height: 150.0,
      child: ListView.builder(
          padding: const EdgeInsets.only(left: 8, top: 0, bottom: 0, right: 8),
          scrollDirection: Axis.horizontal,
          itemCount: _forecast.hourly.length,
          itemBuilder: (BuildContext context, int index) {
            return Container(
                padding: const EdgeInsets.only(
                    left: 10, top: 15, bottom: 15, right: 10),
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      )
                    ]),
                child: Column(children: [
                  Text(
                    "${_forecast.hourly[index].temp}°",
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 17,
                        color: Colors.black),
                  ),
                  getWeatherIcon(_forecast.hourly[index].icon),
                  Text(
                    "${getTimeFromTimestamp(_forecast.hourly[index].dt)}",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.grey),
                  ),
                ]));
          }));
}

String getTimeFromTimestamp(int timestamp) {
  var date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  var formatter = DateFormat('h:mm a');
  return formatter.format(date);
}

String getDateFromTimestamp(int timestamp) {
  var date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  var formatter = DateFormat('E');
  return formatter.format(date);
}

Widget dailyBoxes(Forecast _forcast) {
  return Expanded(
      child: ListView.builder(
          shrinkWrap: true,
          physics: ClampingScrollPhysics(),
          padding: const EdgeInsets.only(left: 8, top: 0, bottom: 0, right: 8),
          itemCount: _forcast.daily.length,
          itemBuilder: (BuildContext context, int index) {
            return Container(
                padding: const EdgeInsets.only(
                    left: 10, top: 5, bottom: 5, right: 10),
                margin: const EdgeInsets.all(5),
                child: Row(children: [
                  Expanded(
                      child: Text(
                    "${getDateFromTimestamp(_forcast.daily[index].dt)}",
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  )),
                  Expanded(
                      child: getWeatherIconSmall(_forcast.daily[index].icon)),
                  Expanded(
                      child: Text(
                    "${_forcast.daily[index].high.toInt()}/${_forcast.daily[index].low.toInt()}",
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  )),
                ]));
          }));
}

class Clipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, size.height - 20);

    path.quadraticBezierTo((size.width / 6) * 1, (size.height / 2) + 15,
        (size.width / 3) * 1, size.height - 30);
    path.quadraticBezierTo((size.width / 2) * 1, (size.height + 0),
        (size.width / 3) * 2, (size.height / 4) * 3);
    path.quadraticBezierTo((size.width / 6) * 5, (size.height / 2) - 20,
        size.width, size.height - 60);

    path.lineTo(size.width, size.height - 60);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);

    path.close();

    return path;
  }

  @override
  bool shouldReclip(Clipper oldClipper) => false;
}

Future getCurrentWeather(Location location) async {
  Weather? weather;
  String city = location.city;
  String apiKey = "729b80b4f20cffdcb8afd03a35945d82";
  var url =
      "https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric";

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    weather = Weather.fromJson(jsonDecode(response.body));
  } else {
    throw Exception("Failed to load data");
  }

  return weather;
}

Future getForecast(Location location) async {
  Forecast? forecast;
  String apiKey = "729b80b4f20cffdcb8afd03a35945d82";
  String lat = location.lat;
  String lon = location.lon;
  var url =
      "https://api.openweathermap.org/data/2.5/onecall?lat=$lat&lon=$lon&appid=$apiKey&units=metric";

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    forecast = Forecast.fromJson(jsonDecode(response.body));
  } else {
    throw Exception("Failed to load data");
  }

  return forecast;
}
