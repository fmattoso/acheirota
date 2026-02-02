import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationSession {
  final String id;
  final DateTime startedAt;
  DateTime? endedAt;
  final List<LatLng> plannedRoute;
  List<LatLng> actualRoute = [];
  double totalPlannedDistance; // km
  double totalActualDistance = 0.0; // km
  int totalPlannedDuration; // minutos
  int totalActualDuration = 0; // minutos
  double fuelConsumption; // km/l
  double fuelUsed = 0.0; // litros
  bool isActive = false;
  bool isPaused = false;
  double averageSpeed = 0.0; // km/h
  double maxSpeed = 0.0; // km/h

  // Métricas de desvio
  double maxDeviation = 0.0; // metros
  int recalculationCount = 0;
  DateTime? lastRecalculation;

  // Status atual
  LatLng? currentPosition;
  double? currentSpeed; // km/h
  double? remainingDistance; // km
  int? remainingTime; // minutos
  int currentDestinationIndex = 0;

  NavigationSession({
    required this.id,
    required this.plannedRoute,
    required this.totalPlannedDistance,
    required this.totalPlannedDuration,
    required this.fuelConsumption,
  }) : startedAt = DateTime.now();

  void updatePosition(LatLng position, double speed) {
    currentPosition = position;
    currentSpeed = speed;

    // Atualizar rota atual
    actualRoute.add(position);

    // Atualizar velocidade máxima
    if (speed > maxSpeed) {
      maxSpeed = speed;
    }

    // Calcular média de velocidade
    if (actualRoute.length > 1) {
      final totalSpeed = averageSpeed * (actualRoute.length - 1) + speed;
      averageSpeed = totalSpeed / actualRoute.length;
    } else {
      averageSpeed = speed;
    }
  }

  void addDistance(double distance) {
    totalActualDistance += distance;
    fuelUsed = totalActualDistance / fuelConsumption;
  }

  void addDuration(int duration) {
    totalActualDuration += duration;
  }

  void recalculate() {
    recalculationCount++;
    lastRecalculation = DateTime.now();
  }

  void pause() {
    isPaused = true;
  }

  void resume() {
    isPaused = false;
  }

  void end() {
    endedAt = DateTime.now();
    isActive = false;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'totalPlannedDistance': totalPlannedDistance,
      'totalActualDistance': totalActualDistance,
      'totalPlannedDuration': totalPlannedDuration,
      'totalActualDuration': totalActualDuration,
      'fuelConsumption': fuelConsumption,
      'fuelUsed': fuelUsed,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'maxDeviation': maxDeviation,
      'recalculationCount': recalculationCount,
      'currentDestinationIndex': currentDestinationIndex,
    };
  }
}