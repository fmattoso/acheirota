import 'package:google_maps_flutter/google_maps_flutter.dart';

enum NavigationStatus {
  inProgress,
  paused,
  completed,
  deviated,
  recalculating,
}

class NavigationSession {
  final DateTime startTime;
  DateTime? endTime;
  final List<LatLng> routePoints;
  final double totalDistance; // em metros
  final Duration totalDuration;
  final double fuelConsumption; // km/l

  // Estado atual
  LatLng? currentPosition;
  double currentSpeed; // km/h
  double distanceTraveled; // metros
  double remainingDistance; // metros
  Duration remainingDuration;
  double averageSpeed; // km/h
  List<LatLng> positions; // Histórico de posições
  NavigationStatus status;
  DateTime lastUpdate;

  NavigationSession({
    required this.startTime,
    this.endTime,
    required this.routePoints,
    required this.totalDistance,
    required this.totalDuration,
    required this.fuelConsumption,
    required this.remainingDistance,
    required this.remainingDuration,
    this.currentPosition,
    this.currentSpeed = 0,
    this.distanceTraveled = 0,
    this.averageSpeed = 0,
    List<LatLng>? positions,
    this.status = NavigationStatus.inProgress,
    required this.lastUpdate,
  }) : positions = positions ?? [];

  // Adicionar nova posição ao histórico
  void addPosition(LatLng position) {
    positions.add(position);
  }

  // Calcular consumo de combustível até o momento
  double get fuelUsed {
    return distanceTraveled / 1000 / fuelConsumption;
  }

  // Calcular tempo decorrido
  Duration get elapsedDuration {
    return DateTime.now().difference(startTime);
  }

  // Calcular progresso (0.0 a 1.0)
  double get progress {
    if (totalDistance <= 0) return 0;
    return (distanceTraveled / totalDistance).clamp(0.0, 1.0);
  }

  // Calcular ETA
  DateTime get estimatedArrival {
    return DateTime.now().add(remainingDuration);
  }

  // Formatar para exibição
  String get formattedRemainingDistance {
    if (remainingDistance < 1000) {
      return '${remainingDistance.round()} m';
    } else {
      return '${(remainingDistance / 1000).toStringAsFixed(1)} km';
    }
  }

  String get formattedRemainingTime {
    final hours = remainingDuration.inHours;
    final minutes = remainingDuration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes} min';
    }
  }

  String get formattedCurrentSpeed {
    return '${currentSpeed.round()} km/h';
  }
}