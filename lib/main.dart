import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:new_weather_app/current_weather.dart';
import 'package:new_weather_app/models/location.dart';
import 'package:hive_flutter/hive_flutter.dart';


void main() async {
  await Hive.initFlutter();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  List<Location> locations = [
    Location(
      city: 'Minsk',
      country: 'BY',
      lat: '53.9',
      lon: '27.5667',
    )
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CurrentWeatherPage(locations, context),
    );
  }
}
