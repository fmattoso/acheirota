import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingAutocompleteService {
  final String apiKey;

  GeocodingAutocompleteService(this.apiKey);

  // Método PRINCIPAL melhorado para buscar sugestões
  Future<List<Map<String, dynamic>>> getSuggestions(String input) async {
    try {
      if (input.length < 3) {
        return [];
      }

      print('📍 Buscando sugestões para: "$input"');

      // Extrair componentes do input
      final parsedInput = _parseAddressInput(input);
      print('   Componentes extraídos:');
      print('     - Rua: ${parsedInput['street']}');
      print('     - Número: ${parsedInput['number']}');
      print('     - Bairro: ${parsedInput['neighborhood']}');
      print('     - Cidade: ${parsedInput['city']}');

      // Tentar primeiro com geocoding preciso se tiver número
      if (parsedInput['number']!.isNotEmpty && parsedInput['street']!.isNotEmpty) {
        final preciseResults = await _getPreciseGeocoding(
          parsedInput['street']!,
          parsedInput['number']!,
          parsedInput['city']!,
          parsedInput['neighborhood']!,
        );

        if (preciseResults.isNotEmpty) {
          print('✅ Encontrados ${preciseResults.length} resultados precisos');
          return preciseResults;
        }
      }

      // Fallback: busca geral
      return await _getGeneralGeocoding(input);

    } catch (e) {
      print('❌ Erro em getSuggestions: $e');
      return await _getGeneralGeocoding(input); // Fallback seguro
    }
  }

  // ANÁLISE DO INPUT: Extrai rua, número, bairro, cidade
  Map<String, String> _parseAddressInput(String input) {
    Map<String, String> result = {
      'street': '',
      'number': '',
      'neighborhood': '',
      'city': '',
      'fullStreet': input.trim(),
    };

    try {
      // Padrões comuns no Brasil
      final patterns = [
        // "Rua Exemplo, 123, Bairro, Cidade"
        RegExp(r'^(.*?)\s*,\s*(\d+[A-Za-z]?)\s*(?:,|\s+)(.*?)(?:\s*,\s*(.*))?$'),
        // "Av. Exemplo 123 - Bairro - Cidade"
        RegExp(r'^(.*?)\s+(\d+[A-Za-z]?)\s*(?:-|\s+)(.*?)(?:\s*(?:-|\s+)(.*))?$'),
        // "Rua Exemplo, 123"
        RegExp(r'^(.*?)\s*,\s*(\d+[A-Za-z]?)$'),
        // "Rua Exemplo 123"
        RegExp(r'^(.*?)\s+(\d+[A-Za-z]?)$'),
      ];

      for (var pattern in patterns) {
        final match = pattern.firstMatch(input);
        if (match != null) {
          if (match.groupCount >= 1) result['street'] = match.group(1)?.trim() ?? '';
          if (match.groupCount >= 2) result['number'] = match.group(2)?.trim() ?? '';
          if (match.groupCount >= 3) result['neighborhood'] = match.group(3)?.trim() ?? '';
          if (match.groupCount >= 4) result['city'] = match.group(4)?.trim() ?? '';
          break;
        }
      }

      // Se não encontrou padrão, tentar extrair número no final
      if (result['number']!.isEmpty) {
        final numberMatch = RegExp(r'(\d+[A-Za-z]?\b)(?!.*\d)').firstMatch(input);
        if (numberMatch != null) {
          result['number'] = numberMatch.group(1) ?? '';
          result['street'] = input.substring(0, numberMatch.start).trim();
        }
      }

      // Limpar "Rua", "Av", etc do início
      final streetPrefixes = ['rua', 'av', 'avenida', 'al', 'alameda', 'travessa', 'praça'];
      for (var prefix in streetPrefixes) {
        if (result['street']!.toLowerCase().startsWith('$prefix ')) {
          result['street'] = result['street']!.substring(prefix.length).trim();
          break;
        }
      }

    } catch (e) {
      print('⚠️  Erro ao parsear input: $e');
    }

    return result;
  }

  // GEOCODING PRECISO: Usa components para melhor resultado
  Future<List<Map<String, dynamic>>> _getPreciseGeocoding(
      String street,
      String number,
      String city,
      String neighborhood,
      ) async {
    try {
      // Construir query otimizada
      String query = '$street $number';
      if (neighborhood.isNotEmpty) {
        query += ' $neighborhood';
      }
      if (city.isNotEmpty) {
        query += ' $city';
      }

      // Construir components para precisão
      String components = 'country:BR';
      if (city.isNotEmpty) {
        components += '|locality:${Uri.encodeQueryComponent(city)}';
      }

      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
              '?address=${Uri.encodeQueryComponent(query)}'
              '&components=$components'
              '&key=$apiKey'
              '&language=pt-BR'
              '&region=br'
      );

      print('   🎯 Geocoding preciso para: $street $number');
      print('   📡 URL: ${url.toString().replaceAll(apiKey, 'API_KEY_HIDDEN')}');

      final response = await http.get(url);

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body);
      print('   📊 Status: ${data['status']}');

      if (data['status'] == 'OK') {
        return _processGeocodingResults(data['results'] as List, true);
      }

      return [];
    } catch (e) {
      print('   ❌ Erro no geocoding preciso: $e');
      return [];
    }
  }

  // GEOCODING GERAL: Fallback para quando não temos componentes claros
  Future<List<Map<String, dynamic>>> _getGeneralGeocoding(String input) async {
    try {
      final encodedInput = Uri.encodeQueryComponent(input);
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
              '?address=$encodedInput'
              '&key=$apiKey'
              '&language=pt-BR'
              '&region=br'
              '&components=country:BR'
      );

      print('   🔍 Geocoding geral para: $input');

      final response = await http.get(url);

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        return _processGeocodingResults(data['results'] as List, false);
      }

      return [];
    } catch (e) {
      print('   ❌ Erro no geocoding geral: $e');
      return [];
    }
  }

  // PROCESSAR RESULTADOS DO GEOCODING
  List<Map<String, dynamic>> _processGeocodingResults(List results, bool isPreciseSearch) {
    return results.map((result) {
      final address = result['formatted_address'] ?? 'Endereço não disponível';
      final location = result['geometry']['location'];
      final lat = location['lat'] is int
          ? (location['lat'] as int).toDouble()
          : location['lat'] as double;
      final lng = location['lng'] is int
          ? (location['lng'] as int).toDouble()
          : location['lng'] as double;

      // Extrair componentes do endereço
      final components = result['address_components'] as List;
      Map<String, String> addressInfo = _extractAddressInfo(components);

      // Construir endereço formatado
      final formattedAddress = _buildFormattedAddress(addressInfo, address);

      // Determinar precisão
      final accuracy = _calculateAddressAccuracy(addressInfo, isPreciseSearch);

      print('   📍 Resultado: $formattedAddress');
      print('   📍 Precisão: ${accuracy['score']}/10 - ${accuracy['description']}');
      print('   📍 Coordenadas: $lat, $lng');

      return {
        'description': formattedAddress,
        'address': formattedAddress,
        'mainText': _buildMainText(addressInfo, formattedAddress),
        'secondaryText': _buildSecondaryText(addressInfo),
        'latitude': lat,
        'longitude': lng,
        'placeId': result['place_id'] ?? '',
        'street': addressInfo['street'] ?? '',
        'number': addressInfo['number'] ?? '',
        'neighborhood': addressInfo['neighborhood'] ?? '',
        'city': addressInfo['city'] ?? '',
        'state': addressInfo['state'] ?? '',
        'accuracy': accuracy['score'],
        'accuracyDescription': accuracy['description'],
        'hasNumber': addressInfo['number']?.isNotEmpty ?? false,
      };
    }).toList();
  }

  // EXTRAIR INFORMAÇÕES DO ENDEREÇO
  Map<String, String> _extractAddressInfo(List components) {
    Map<String, String> info = {
      'street': '',
      'number': '',
      'neighborhood': '',
      'city': '',
      'state': '',
    };

    for (var component in components) {
      final types = List<String>.from(component['types']);
      final name = component['long_name'] as String;
      final shortName = component['short_name'] as String;

      if (types.contains('street_number')) {
        info['number'] = name;
      } else if (types.contains('route')) {
        info['street'] = name;
      } else if (types.contains('sublocality') || types.contains('neighborhood')) {
        info['neighborhood'] = name;
      } else if (types.contains('administrative_area_level_2') ||
          types.contains('locality')) {
        info['city'] = name;
      } else if (types.contains('administrative_area_level_1')) {
        info['state'] = shortName; // Usar sigla (SP, PR, etc)
      }
    }

    return info;
  }

  // CONSTRUIR ENDEREÇO FORMATADO
  String _buildFormattedAddress(Map<String, String> info, String originalAddress) {
    if (info['street']!.isNotEmpty && info['number']!.isNotEmpty) {
      // Construir endereço ideal: Rua, Número - Bairro, Cidade - Estado
      List<String> parts = [];
      parts.add('${info['street']}, ${info['number']}');

      if (info['neighborhood']!.isNotEmpty) {
        parts.add(info['neighborhood']!);
      }

      if (info['city']!.isNotEmpty) {
        if (info['state']!.isNotEmpty) {
          parts.add('${info['city']!} - ${info['state']!}');
        } else {
          parts.add(info['city']!);
        }
      }

      return parts.join(', ');
    }

    return originalAddress;
  }

  // TEXTO PRINCIPAL PARA EXIBIÇÃO
  String _buildMainText(Map<String, String> info, String fallback) {
    if (info['street']!.isNotEmpty && info['number']!.isNotEmpty) {
      return '${info['street']}, ${info['number']}';
    } else if (info['street']!.isNotEmpty) {
      return info['street']!;
    }

    final parts = fallback.split(',');
    return parts.isNotEmpty ? parts[0].trim() : fallback;
  }

  // TEXTO SECUNDÁRIO PARA EXIBIÇÃO
  String _buildSecondaryText(Map<String, String> info) {
    List<String> parts = [];

    if (info['neighborhood']!.isNotEmpty) {
      parts.add(info['neighborhood']!);
    }

    if (info['city']!.isNotEmpty) {
      if (info['state']!.isNotEmpty) {
        parts.add('${info['city']!} - ${info['state']!}');
      } else {
        parts.add(info['city']!);
      }
    }

    return parts.join(', ');
  }

  // CALCULAR PRECISÃO DO ENDEREÇO
  Map<String, dynamic> _calculateAddressAccuracy(Map<String, String> info, bool isPreciseSearch) {
    int score = 0;
    List<String> descriptions = [];

    // Pontuar componentes presentes
    if (info['street']!.isNotEmpty) score += 3;
    if (info['number']!.isNotEmpty) score += 4;
    if (info['neighborhood']!.isNotEmpty) score += 1;
    if (info['city']!.isNotEmpty) score += 1;
    if (info['state']!.isNotEmpty) score += 1;

    // Bônus para busca precisa
    if (isPreciseSearch) score += 2;

    // Determinar descrição
    if (score >= 8) {
      descriptions.add('Endereço completo');
    } else if (score >= 5) {
      descriptions.add('Endereço parcial');
    } else {
      descriptions.add('Aproximado');
    }

    if (info['number']!.isNotEmpty) {
      descriptions.add('Com número');
    } else {
      descriptions.add('Sem número');
    }

    return {
      'score': score.clamp(0, 10),
      'description': descriptions.join(' • '),
    };
  }

  // MÉTODO DE GEOCODING DIRETO (para quando usuário digita manualmente)
  Future<Map<String, dynamic>?> geocode(String address) async {
    try {
      if (address.isEmpty) return null;

      print('📍 Geocoding direto para: "$address"');

      // Primeiro tentar análise e geocoding preciso
      final parsed = _parseAddressInput(address);

      if (parsed['number']!.isNotEmpty && parsed['street']!.isNotEmpty) {
        final preciseResults = await _getPreciseGeocoding(
          parsed['street']!,
          parsed['number']!,
          parsed['city']!,
          parsed['neighborhood']!,
        );

        if (preciseResults.isNotEmpty) {
          print('✅ Geocoding preciso bem-sucedido');
          return preciseResults.first;
        }
      }

      // Fallback para geocoding geral
      final generalResults = await _getGeneralGeocoding(address);

      if (generalResults.isNotEmpty) {
        print('✅ Geocoding geral bem-sucedido');
        return generalResults.first;
      }

      print('⚠️  Nenhum resultado encontrado');
      return null;

    } catch (e) {
      print('❌ Erro no geocoding direto: $e');
      return null;
    }
  }
}