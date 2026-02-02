import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacesService {
  final String apiKey;

  PlacesService(this.apiKey);

  // NOVA API PLACES - Autocomplete CORRIGIDO
  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(String input) async {
    try {
      if (input.length < 3) return [];

      print('📍 Buscando sugestões para: "$input"');

      // URL DA NOVA API PLACES (CORRETA)
      final url = Uri.parse(
          'https://places.googleapis.com/v1/places:autocomplete'
      );

      // Corpo da requisição CORRETO
      final body = json.encode({
        'input': input,
        'languageCode': 'pt-BR',
        'regionCode': 'BR',
        'locationBias': {
          'circle': {
            'center': {
              'latitude': -23.5505,  // São Paulo
              'longitude': -46.6333
            },
            'radius': 50000.0  // 50km
          }
        }
      });

      // Headers CORRETOS
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'suggestions.placePrediction.text,suggestions.placePrediction.place'
      };

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('📥 Resposta: ${response.body}');

        // Fallback para Geocoding API
        return await _getGeocodingSuggestions(input);
      }

      final data = json.decode(response.body);

      if (data.containsKey('suggestions')) {
        final suggestions = data['suggestions'] as List;
        print('✅ Encontradas ${suggestions.length} sugestões');

        final results = suggestions
            .where((suggestion) => suggestion['placePrediction'] != null)
            .map((suggestion) {
          final prediction = suggestion['placePrediction'];
          final text = prediction['text']?['text'] ?? '';
          final placeId = prediction['place'] ?? '';

          return {
            'description': text,
            'placeId': placeId,
            'mainText': text,
            'secondaryText': '',
          };
        })
            .toList();

        print('📋 Primeira sugestão: ${results.isNotEmpty ? results.first['description'] : "Nenhuma"}');
        return results;
      }

      return [];
    } catch (e) {
      print('❌ Erro no autocomplete: $e');
      // Fallback para Geocoding
      return await _getGeocodingSuggestions(input);
    }
  }

  // Método usando Geocoding API (funciona melhor)
  Future<List<Map<String, dynamic>>> _getGeocodingSuggestions(String input) async {
    try {
      if (input.length < 3) return [];

      final encodedInput = Uri.encodeQueryComponent(input);

      // Usar Geocoding API - mais confiável
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
              '?address=$encodedInput'
              '&key=$apiKey'
              '&language=pt-BR'
              '&region=br'
              '&bounds=34.0,-118.5|34.2,-118.2'  // Opcional: limitar área
      );

      print('🔄 Usando Geocoding API como fallback');

      final response = await http.get(url);

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body);
      print('📊 Status Geocoding: ${data['status']}');

      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        print('✅ Encontrados ${results.length} endereços');

        return results
            .map((result) {
          final address = result['formatted_address'] ?? '';
          final location = result['geometry']['location'];

          // Simplificar para mostrar apenas parte do endereço
          String mainText = address;
          if (address.length > 50) {
            mainText = '${address.substring(0, 50)}...';
          }

          return {
            'description': address,
            'placeId': result['place_id'] ?? '',
            'mainText': mainText,
            'secondaryText': '',
            'latitude': location['lat'],
            'longitude': location['lng'],
          };
        })
            .toList();
      }

      return [];
    } catch (e) {
      print('❌ Erro no Geocoding fallback: $e');
      return [];
    }
  }

  // Obter detalhes do lugar usando Place Details API
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      // Usar Place Details API (funciona com place_id do Geocoding)
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
              '?place_id=$placeId'
              '&key=$apiKey'
              '&language=pt-BR'
              '&fields=name,formatted_address,geometry'
      );

      print('🔍 Buscando detalhes para: $placeId');

      final response = await http.get(url);

      if (response.statusCode != 200) {
        print('❌ Erro HTTP: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      print('📊 Status Details: ${data['status']}');

      if (data['status'] == 'OK') {
        final result = data['result'];
        final location = result['geometry']['location'];

        return {
          'name': result['name'] ?? '',
          'address': result['formatted_address'] ?? '',
          'latitude': location['lat'],
          'longitude': location['lng'],
        };
      }

      // Se Place Details falhar, tentar Geocoding inverso
      return await _reverseGeocode(placeId);

    } catch (e) {
      print('❌ Erro ao obter detalhes: $e');
      return null;
    }
  }

  // Fallback: Geocoding inverso
  Future<Map<String, dynamic>?> _reverseGeocode(String placeId) async {
    try {
      // Para simplificar, retornar null e usar geocoding normal depois
      return null;
    } catch (e) {
      return null;
    }
  }

  // Método direto usando Geocoding (para adicionar destino sem autocomplete)
  Future<Map<String, dynamic>?> geocodeAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeQueryComponent(address);
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
              '?address=$encodedAddress'
              '&key=$apiKey'
              '&language=pt-BR'
              '&region=br'
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final result = data['results'][0];
        final location = result['geometry']['location'];

        return {
          'name': result['formatted_address'],
          'address': result['formatted_address'],
          'latitude': location['lat'],
          'longitude': location['lng'],
        };
      }
      return null;
    } catch (e) {
      print('❌ Erro no geocoding direto: $e');
      return null;
    }
  }
}