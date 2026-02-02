import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  Future<Position> getCurrentLocation() async {
    // Verificar se o serviço de localização está habilitado
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Serviço de localização desabilitado');
    }

    // Verificar e solicitar permissões
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permissão de localização negada');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização permanentemente negada');
    }

    // NOVA API com LocationSettings
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high, // Substitui desiredAccuracy
        distanceFilter: 10, // em metros - opcional
        timeLimit: const Duration(seconds: 30), // timeout opcional
      ),
    );
  }

  // Alternativa: Configurações específicas por plataforma
  Future<Position> getCurrentLocationWithPlatformSettings() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Serviço de localização desabilitado');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permissão de localização negada');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização permanentemente negada');
    }

    // Configurações específicas por plataforma
    return await Geolocator.getCurrentPosition(
      locationSettings: Platform.isAndroid
          ? AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: false, // Usa FusedLocationProvider por padrão
        intervalDuration: const Duration(seconds: 10), // Android específico
      )
          : AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.other,
        distanceFilter: 10,
      ),
    );
  }

  // Método para obter atualizações contínuas de localização
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Só emite quando move pelo menos 10 metros
      ),
    );
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return formatAddress(place);
      }
      return 'Endereço não encontrado';
    } catch (e) {
      return 'Erro ao obter endereço: $e';
    }
  }

  // Formata o endereço de forma mais legível
  String formatAddress(Placemark place) {
    List<String> parts = [];

    if (place.street?.isNotEmpty == true) parts.add(place.street!);
    if (place.subLocality?.isNotEmpty == true) parts.add(place.subLocality!);
    if (place.locality?.isEmpty == false) {
      parts.add(place.locality!);
    } else if (place.subAdministrativeArea?.isNotEmpty == true) {
      parts.add(place.subAdministrativeArea!);
    }

    return parts.join(', ');
  }

  Future<Map<String, double>> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return {
          'latitude': locations.first.latitude,
          'longitude': locations.first.longitude,
        };
      }
      throw Exception('Endereço não encontrado');
    } catch (e) {
      rethrow;
    }
  }

  // Calcular distância entre dois pontos
  Future<double> calculateDistance(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) async {
    return Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    ) / 1000; // Retorna em km
  }

  // Verificar se está dentro de um raio
  Future<bool> isWithinRadius(
      double centerLat,
      double centerLng,
      double radiusKm,
      ) async {
    try {
      Position currentPosition = await getCurrentLocation();
      double distance = await calculateDistance(
        centerLat,
        centerLng,
        currentPosition.latitude,
        currentPosition.longitude,
      );
      return distance <= radiusKm;
    } catch (e) {
      return false;
    }
  }

  // Obter última posição conhecida (mais rápido)
  Future<Position?> getLastKnownPosition() async {
    return await Geolocator.getLastKnownPosition();
  }
}