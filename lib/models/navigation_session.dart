import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';

enum NavigationStatus {
  inProgress,
  paused,
  completed,
  deviated,
  recalculating,
}

// Classe auxiliar para armazenar posição com timestamp
class PositionWithTime {
  final LatLng position;
  final DateTime timestamp;
  final double? speed; // km/h
  final double? heading; // graus

  PositionWithTime({
    required this.position,
    required this.timestamp,
    this.speed,
    this.heading,
  });

  // Converter de LatLng
  factory PositionWithTime.fromLatLng(LatLng position, {double? speed, double? heading}) {
    return PositionWithTime(
      position: position,
      timestamp: DateTime.now(),
      speed: speed,
      heading: heading,
    );
  }
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
  List<PositionWithTime> positions; // Histórico de posições com timestamp
  NavigationStatus status;
  DateTime lastUpdate;
  double? currentHeading; // graus (0-360)

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
    List<PositionWithTime>? positions,
    this.status = NavigationStatus.inProgress,
    required this.lastUpdate,
    this.currentHeading,
  }) : positions = positions ?? [];

  // Adicionar nova posição ao histórico
  void addPosition(LatLng position, {double? speed, double? heading}) {
    positions.add(PositionWithTime.fromLatLng(position, speed: speed, heading: heading));

    // Manter histórico limitado para performance
    if (positions.length > 100) {
      positions.removeAt(0);
    }
  }

  // Obter última posição
  PositionWithTime? get lastPosition {
    if (positions.isEmpty) return null;
    return positions.last;
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

  String get formattedCurrentHeading {
    if (currentHeading == null) return '--°';
    return '${currentHeading!.round()}°';
  }

  // Calcular velocidade média baseada no histórico
  double calculateAverageSpeedFromHistory() {
    if (positions.length < 2) return currentSpeed;

    try {
      final first = positions.first;
      final last = positions.last;

      final totalTime = last.timestamp.difference(first.timestamp).inSeconds;
      if (totalTime <= 0) return currentSpeed;

      double totalDistance = 0;
      for (int i = 1; i < positions.length; i++) {
        final p1 = positions[i-1].position;
        final p2 = positions[i].position;

        // Calcular distância entre pontos usando fórmula de Haversine
        final lat1 = p1.latitude * (pi / 180);
        final lon1 = p1.longitude * (pi / 180);
        final lat2 = p2.latitude * (pi / 180);
        final lon2 = p2.longitude * (pi / 180);

        final dLat = lat2 - lat1;
        final dLon = lon2 - lon1;

        final a = sin(dLat/2) * sin(dLat/2) +
            cos(lat1) * cos(lat2) *
                sin(dLon/2) * sin(dLon/2);
        final c = 2 * atan2(sqrt(a), sqrt(1-a));
        final distance = 6371000 * c; // Raio da Terra em metros

        totalDistance += distance;
      }

      final averageSpeedMs = totalDistance / totalTime;
      return averageSpeedMs * 3.6; // Converter para km/h
    } catch (e) {
      print('Erro ao calcular velocidade média: $e');
      return currentSpeed;
    }
  }

  // Calcular heading médio dos últimos pontos
  double? calculateAverageHeading() {
    if (positions.isEmpty) return currentHeading;

    try {
      // Filtrar posições com heading válido
      final validHeadings = positions
          .where((p) => p.heading != null && !p.heading!.isNaN)
          .map((p) => p.heading!)
          .toList();

      if (validHeadings.isEmpty) return currentHeading;

      // Calcular média circular para heading
      double sinSum = 0;
      double cosSum = 0;

      for (final heading in validHeadings) {
        final rad = heading * (pi / 180);
        sinSum += sin(rad);
        cosSum += cos(rad);
      }

      final avgRad = atan2(sinSum / validHeadings.length, cosSum / validHeadings.length);
      double avgHeading = avgRad * (180 / pi);

      // Normalizar para 0-360
      avgHeading = (avgHeading + 360) % 360;

      return avgHeading;
    } catch (e) {
      print('Erro ao calcular heading médio: $e');
      return currentHeading;
    }
  }
}