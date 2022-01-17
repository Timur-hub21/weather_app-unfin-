import 'package:flutter/material.dart';
import 'package:new_weather_app/current_weather.dart';
import 'package:new_weather_app/models/location.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  List<Location> locations = [Location(
    city: 'Minsk', country: 'BY', lat: '53.9', lon: '27.5667',)
    ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home:CurrentWeatherPage(locations, context),
    );
  }
}
