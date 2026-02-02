import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/route_calculation.dart';

class StorageService {
  static const String _routeKey = 'current_route';
  static const String _fuelKey = 'fuel_consumption';

  Future<void> saveRoute(RouteCalculation route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routeKey, jsonEncode(route.toMap()));
  }

  Future<RouteCalculation?> loadRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final routeString = prefs.getString(_routeKey);

    if (routeString != null) {
      try {
        final routeMap = jsonDecode(routeString);
        return RouteCalculation.fromMap(routeMap);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> deleteRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_routeKey);
  }

  Future<void> saveFuelConsumption(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fuelKey, value);
  }

  Future<double> loadFuelConsumption() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fuelKey) ?? 10.0;
  }
}