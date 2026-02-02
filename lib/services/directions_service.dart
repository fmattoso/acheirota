import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps; // Alias para evitar conflito
import '../models/destination.dart';

class DirectionsService {
  final String apiKey;

  DirectionsService(this.apiKey);

  Future<Map<String, dynamic>> calculateOptimalRoute(
      double startLat,
      double startLng,
      List<Destination> destinations,
      ) async {
    print('📍 Iniciando cálculo de rota...');
    print('   Ponto inicial: $startLat, $startLng');
    print('   Número de destinos: ${destinations.length}');

    if (destinations.isEmpty) {
      return {
        'destinations': [],
        'polylinePoints': [],
        'totalDistance': 0.0,
        'travelDuration': 0,
      };
    }

    try {
      // Verificar se destinos têm coordenadas válidas
      for (var dest in destinations) {
        if (!_isValidCoordinate(dest.latitude, dest.longitude)) {
          throw Exception('Coordenadas inválidas para destino: ${dest.label}');
        }
      }

      // Ordenar destinos por proximidade
      List<Destination> sortedDestinations = await _sortDestinationsByProximity(
        startLat,
        startLng,
        destinations,
      );

      print('📍 Destinos ordenados:');
      for (var i = 0; i < sortedDestinations.length; i++) {
        print('   ${i + 1}. ${sortedDestinations[i].label}: '
            '${sortedDestinations[i].latitude}, ${sortedDestinations[i].longitude}');
      }

      // Calcular rotas entre pontos consecutivos
      List<maps.LatLng> allPolylinePoints = []; // Usar maps.LatLng
      double totalDistance = 0.0;
      double totalDuration = 0.0;

      // Calcular rota do ponto inicial até o primeiro destino
      var firstRoute = await _getRouteBetweenPoints(
        startLat,
        startLng,
        sortedDestinations.first.latitude,
        sortedDestinations.first.longitude,
      );

      totalDistance += firstRoute['distance'] ?? 0.0;
      totalDuration += firstRoute['duration'] ?? 0;
      allPolylinePoints.addAll(firstRoute['points'] ?? []);
      print('   🛣️  Rota inicial: ${firstRoute['distance']?.toStringAsFixed(2)} km, '
          '${firstRoute['duration']} min');

      // Calcular rotas entre destinos consecutivos
      for (int i = 1; i < sortedDestinations.length; i++) {
        var prevDest = sortedDestinations[i - 1];
        var currentDest = sortedDestinations[i];

        var route = await _getRouteBetweenPoints(
          prevDest.latitude,
          prevDest.longitude,
          currentDest.latitude,
          currentDest.longitude,
        );

        totalDistance += route['distance'] ?? 0.0;
        totalDuration += route['duration'] ?? 0.0;
        allPolylinePoints.addAll(route['points'] ?? []);
        print('   🛣️  Rota ${i}: ${route['distance']?.toStringAsFixed(2)} km, '
            '${route['duration']} min');
      }

      // Adicionar tempos de parada
      for (var dest in sortedDestinations) {
        totalDuration += dest.stopDuration;
      }

      print('📍 Cálculo finalizado:');
      print('   Distância total: ${totalDistance.toStringAsFixed(2)} km');
      print('   Duração total: $totalDuration min');
      print('   Pontos da polyline: ${allPolylinePoints.length}');

      return {
        'destinations': sortedDestinations,
        'polylinePoints': allPolylinePoints, // Já é List<maps.LatLng>
        'totalDistance': totalDistance,
        'travelDuration': totalDuration,
      };
    } catch (e) {
      print('❌ Erro ao calcular rota: $e');
      rethrow;
    }
  }

  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 &&
        lng >= -180 && lng <= 180 &&
        !(lat == 0 && lng == 0);
  }

  Future<Map<String, dynamic>> _getRouteBetweenPoints(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) async {
    try {
      // Verificar se as coordenadas são válidas
      if (!_isValidCoordinate(startLat, startLng) ||
          !_isValidCoordinate(endLat, endLng)) {
        throw Exception('Coordenadas inválidas: '
            '($startLat, $startLng) -> ($endLat, $endLng)');
      }

      // Verificar se os pontos são diferentes
      final distance = await Geolocator.distanceBetween(
        startLat, startLng, endLat, endLng,
      );

      if (distance < 10) {
        print('⚠️  Pontos muito próximos ($distance metros), usando rota mínima');
        return {
          'points': [
            maps.LatLng(startLat, startLng),
            maps.LatLng(endLat, endLng),
          ],
          'distance': 0.0,
          'duration': 0,
        };
      }

      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
              '?origin=$startLat,$startLng'
              '&destination=$endLat,$endLng'
              '&key=$apiKey'
              '&language=pt-BR'
              '&mode=driving'
      );

      print('   🌐 Chamando Directions API:');
      print('      Origem: $startLat, $startLng');
      print('      Destino: $endLat, $endLng');

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Falha na requisição: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      print('   📊 Status da resposta: ${data['status']}');

      if (data['status'] != 'OK') {
        final errorMsg = data['error_message'] ?? 'Sem mensagem';
        print('   ❌ Erro da API: ${data['status']} - $errorMsg');

        if (data['status'] == 'ZERO_RESULTS') {
          print('   🔄 Tentando com pequena variação...');
          final variedEndLat = endLat + 0.0001;
          final variedEndLng = endLng + 0.0001;

          return await _getRouteBetweenPoints(
            startLat, startLng, variedEndLat, variedEndLng,
          );
        }

        throw Exception('Erro da API: ${data['status']} - $errorMsg');
      }

      // Processar a resposta
      List<maps.LatLng> points = [];
      double distanceKm = 0.0;
      double duration = 0.0;

      if (data['routes'].isNotEmpty && data['routes'][0]['legs'].isNotEmpty) {
        PolylinePoints polylinePoints = PolylinePoints(apiKey: apiKey);
        String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
        List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(encodedPolyline);

        points = decodedPoints
            .map((point) => maps.LatLng(point.latitude, point.longitude))
            .toList();

        // Calcular distância e duração
        for (var leg in data['routes'][0]['legs']) {
          distanceKm += (leg['distance']['value'] ?? 0) / 1000.0;
          duration += ((leg['duration']['value'] ?? 0) / 60.0).round();
        }

        print('   ✅ Rota encontrada: ${distanceKm.toStringAsFixed(2)} km, $duration min');
      }

      return {
        'points': points,
        'distance': distanceKm,
        'duration': duration,
      };
    } catch (e) {
      print('   ❌ Erro em _getRouteBetweenPoints: $e');
      rethrow;
    }
  }

  Future<List<Destination>> _sortDestinationsByProximity(
      double startLat,
      double startLng,
      List<Destination> destinations,
      ) async {
    if (destinations.length <= 1) return destinations;

    List<Destination> sorted = [];
    List<Destination> unsorted = List.from(destinations);

    double currentLat = startLat;
    double currentLng = startLng;

    while (unsorted.isNotEmpty) {
      Destination nearest = unsorted.first;
      double nearestDistance = await _calculateDistance(
        currentLat,
        currentLng,
        nearest.latitude,
        nearest.longitude,
      );

      for (var dest in unsorted) {
        double distance = await _calculateDistance(
          currentLat,
          currentLng,
          dest.latitude,
          dest.longitude,
        );
        if (distance < nearestDistance) {
          nearest = dest;
          nearestDistance = distance;
        }
      }

      sorted.add(nearest);
      unsorted.remove(nearest);
      currentLat = nearest.latitude;
      currentLng = nearest.longitude;
    }

    return List.from(sorted);
  }

  Future<double> _calculateDistance(
      double lat1,
      double lng1,
      double lat2,
      double lng2,
      ) async {
    return await Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000.0;
  }
}

// REMOVA esta linha se existir:
// typedef LatLng = ({double latitude, double longitude});