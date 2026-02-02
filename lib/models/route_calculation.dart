import 'destination.dart';

class RouteCalculation {
  final List<Destination> destinations;
  final double totalDistance; // em km
  final int totalDuration; // em minutos
  final double fuelRequired; // em litros
  final DateTime calculatedAt;

  RouteCalculation({
    required this.destinations,
    required this.totalDistance,
    required this.totalDuration,
    required this.fuelRequired,
    required this.calculatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'destinations': destinations.map((d) => d.toMap()).toList(),
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'fuelRequired': fuelRequired,
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }

  factory RouteCalculation.fromMap(Map<String, dynamic> map) {
    return RouteCalculation(
      destinations: (map['destinations'] as List)
          .map((d) => Destination.fromMap(d))
          .toList(),
      totalDistance: map['totalDistance'],
      totalDuration: map['totalDuration'],
      fuelRequired: map['fuelRequired'],
      calculatedAt: DateTime.parse(map['calculatedAt']),
    );
  }
}