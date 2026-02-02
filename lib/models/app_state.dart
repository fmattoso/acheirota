import 'package:acheirota/models/route_calculation.dart';
import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  double _fuelConsumption = 10.0; // km/l
  RouteCalculation? _currentRoute;
  bool _isRouteActive = false;

  double get fuelConsumption => _fuelConsumption;
  RouteCalculation? get currentRoute => _currentRoute;
  bool get isRouteActive => _isRouteActive;

  void setFuelConsumption(double value) {
    _fuelConsumption = value;
    notifyListeners();
  }

  void setCurrentRoute(RouteCalculation? route) {
    _currentRoute = route;
    _isRouteActive = route != null;
    notifyListeners();
  }

  void clearRoute() {
    _currentRoute = null;
    _isRouteActive = false;
    notifyListeners();
  }
}