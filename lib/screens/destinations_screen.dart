import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/app_state.dart';
import '../models/destination.dart';
import '../models/route_calculation.dart';
import '../services/location_service.dart';
import '../services/directions_service.dart';
import '../services/geocoding_autocomplete_service.dart';
import '../widgets/destination_item.dart';
import '../widgets/improved_autocomplete_field.dart';

const kGoogleApiKey = "AIzaSyAR2UG7GlkN5zQyUOMSTOKVDSFo15bg6rQ";

class DestinationsScreen extends StatefulWidget {
  @override
  _DestinationsScreenState createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends State<DestinationsScreen> {
  final LocationService _locationService = LocationService();
  final DirectionsService _directionsService = DirectionsService(kGoogleApiKey);
  final GeocodingAutocompleteService _autocompleteService =
  GeocodingAutocompleteService(kGoogleApiKey);

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  List<Destination> _destinations = [];
  bool _isCalculating = false;
  bool _isAdding = false;
  bool _isSearching = false;

  List<Map<String, dynamic>> _suggestions = [];
  double? _selectedLat;
  double? _selectedLng;
  String? _selectedAddress;

  Timer? _debounceTimer;

  Future<void> _searchAddress(String query) async {
    if (_debounceTimer != null && _debounceTimer!.isActive) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(Duration(milliseconds: 800), () async {
      if (query.length < 3) {
        setState(() {
          _suggestions.clear();
          _isSearching = false;
        });
        return;
      }

      setState(() => _isSearching = true);

      final results = await _autocompleteService.getSuggestions(query);

      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _addDestination() async {
    final address = _addressController.text.trim();

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Digite um endereço primeiro')),
      );
      return;
    }

    setState(() => _isAdding = true);

    final label = _labelController.text.trim().isNotEmpty
        ? _labelController.text.trim()
        : 'Parada ${_destinations.length + 1}';

    final duration = int.tryParse(_durationController.text) ?? 0;

    try {
      double latitude;
      double longitude;
      String finalAddress;

      // PRIMEIRO: Verificar se temos coordenadas da sugestão selecionada
      if (_selectedLat != null && _selectedLng != null && _selectedAddress != null) {
        latitude = _selectedLat!;
        longitude = _selectedLng!;
        finalAddress = _selectedAddress!;
        print('📍 Usando coordenadas da sugestão selecionada:');
        print('   Endereço: $finalAddress');
        print('   Coordenadas: $latitude, $longitude');
      } else {
        // SEGUNDO: Fazer geocoding do endereço digitado
        print('📍 Fazendo geocoding para: $address');
        final geocoded = await _autocompleteService.geocode(address);
        if (geocoded == null) {
          throw Exception('Endereço não encontrado. Tente ser mais específico.');
        }

        latitude = geocoded['latitude'];
        longitude = geocoded['longitude'];
        finalAddress = geocoded['address'];

        print('📍 Coordenadas obtidas via geocoding:');
        print('   Endereço: $finalAddress');
        print('   Coordenadas: $latitude, $longitude');
      }

      // VALIDAR COORDENADAS
      if (!_isValidCoordinate(latitude, longitude)) {
        throw Exception('Coordenadas inválidas: $latitude, $longitude. '
            'Verifique se o endereço está correto.');
      }

      final destination = Destination(
        id: Uuid().v4(),
        address: finalAddress,
        label: label,
        latitude: latitude,
        longitude: longitude,
        stopDuration: duration,
      );

      setState(() {
        _destinations.add(destination);
        _clearForm();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Destino "$label" adicionado com sucesso!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Erro ao adicionar destino: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro: ${e.toString()}'),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isAdding = false);
    }
  }

  bool _isValidCoordinate(double lat, double lng) {
    // Coordenadas válidas para a Terra
    final isValid = lat >= -90 && lat <= 90 &&
        lng >= -180 && lng <= 180 &&
        !(lat == 0 && lng == 0);

    if (!isValid) {
      print('⚠️  Coordenadas inválidas detectadas: $lat, $lng');
    }

    return isValid;
  }

  void _clearForm() {
    _addressController.clear();
    _labelController.clear();
    _durationController.clear();
    _selectedLat = null;
    _selectedLng = null;
    _selectedAddress = null;
    _suggestions.clear();
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final address = suggestion['address'];
    final lat = suggestion['latitude'];
    final lng = suggestion['longitude'];

    print('📍 Sugestão selecionada:');
    print('   Endereço: $address');
    print('   Coordenadas: $lat, $lng');

    // Validar coordenadas antes de aceitar
    if (_isValidCoordinate(lat, lng)) {
      _addressController.text = address;
      _selectedLat = lat;
      _selectedLng = lng;
      _selectedAddress = address;

      setState(() {
        _suggestions.clear();
      });

      // Preencher label se estiver vazio
      if (_labelController.text.isEmpty) {
        _labelController.text = suggestion['mainText'];
      }
    } else {
      print('❌ Sugestão com coordenadas inválidas rejeitada');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️  Endereço com coordenadas inválidas. Tente outro.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _calculateRoute() async {
    setState(() => _isCalculating = true);

    try {
      // VERIFICAR DESTINOS ANTES DE CALCULAR
      print('📍 Verificando destinos antes do cálculo:');
      bool hasInvalidDestinations = false;

      for (var i = 0; i < _destinations.length; i++) {
        final dest = _destinations[i];
        final isValid = _isValidCoordinate(dest.latitude, dest.longitude);

        print('   ${i + 1}. ${dest.label}');
        print('      Endereço: ${dest.address}');
        print('      Coordenadas: ${dest.latitude}, ${dest.longitude}');
        print('      Válido: $isValid');

        if (!isValid) {
          hasInvalidDestinations = true;
          print('      ❌ DESTINO INVÁLIDO!');
        }
      }

      if (hasInvalidDestinations) {
        throw Exception('Um ou mais destinos têm coordenadas inválidas. '
            'Remova-os e adicione novamente.');
      }

      // Obter localização atual
      final position = await _locationService.getCurrentLocation();
      print('📍 Posição atual: ${position.latitude}, ${position.longitude}');

      // Calcular rota otimizada
      final result = await _directionsService.calculateOptimalRoute(
        position.latitude,
        position.longitude,
        _destinations,
      );

      print('🗺️ Rota calculada com sucesso!');
      print('   Distância total: ${result['totalDistance']} km');
      print('   Duração total: ${result['travelDuration']} min');
      print('   Destinos: ${result['destinations'].length}');

      // Calcular combustível necessário
      final appState = Provider.of<AppState>(context, listen: false);
      final totalDistance = (result['totalDistance'] as num).toDouble();
      final fuelRequired = totalDistance / appState.fuelConsumption;

      final routeCalculation = RouteCalculation(
        destinations: (result['destinations'] as List).cast<Destination>(),
        totalDistance: totalDistance,
        totalDuration: (result['travelDuration'] as num).toInt(),
        fuelRequired: fuelRequired,
        calculatedAt: DateTime.now(),
      );

      // Navegar de volta com o resultado
      Navigator.pop(context, {
        'route': routeCalculation,
        'polylinePoints': result['polylinePoints'] ?? [],
      });

    } catch (e, stackTrace) {
      print('❌ Erro ao calcular rota: $e');
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao calcular rota: ${e.toString()}'),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  void _removeDestination(String id) {
    setState(() {
      _destinations.removeWhere((dest) => dest.id == id);
    });
  }

  void _clearAllDestinations() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limpar todos os destinos?'),
        content: Text('Esta ação removerá todos os ${_destinations.length} destinos da lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _destinations.clear();
              });
              Navigator.pop(context);
            },
            child: Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Adicionar Destinos'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Formulário para adicionar destino
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Novo Destino',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Campo de endereço
                    ImprovedAutocompleteField(
                      controller: _addressController,
                      autocompleteService: _autocompleteService,
                      onPlaceSelected: _onPlaceSelected,
                      labelText: 'Endereço completo *',
                      hintText: 'Digite rua, número, cidade, estado...',
                    ),
                    // Sugestões
                    if (_suggestions.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            final isValid = _isValidCoordinate(
                                suggestion['latitude'],
                                suggestion['longitude']
                            );

                            return ListTile(
                              leading: Icon(
                                isValid ? Icons.location_on : Icons.warning,
                                color: isValid ? Colors.blue : Colors.orange,
                                size: 20,
                              ),
                              title: Text(
                                suggestion['mainText'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isValid ? Colors.black : Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: suggestion['secondaryText'].isNotEmpty
                                  ? Text(
                                suggestion['secondaryText'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isValid ? Colors.grey : Colors.orange,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                                  : null,
                              dense: true,
                              enabled: isValid,
                              onTap: isValid ? () => _selectSuggestion(suggestion) : null,
                            );
                          },
                        ),
                      ),

                    SizedBox(height: 12),
                    TextField(
                      controller: _labelController,
                      decoration: InputDecoration(
                        labelText: 'Rótulo (opcional)',
                        hintText: 'Ex: Casa, Trabalho, Mercado',
                        prefixIcon: Icon(Icons.label, color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _durationController,
                      decoration: InputDecoration(
                        labelText: 'Tempo de parada (minutos)',
                        hintText: 'Ex: 30',
                        prefixIcon: Icon(Icons.access_time, color: Colors.orange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isAdding ? null : _addDestination,
                        icon: _isAdding
                            ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Icon(Icons.add_location_alt),
                        label: Text(_isAdding ? 'Adicionando...' : 'Adicionar Destino'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Botão calcular rota
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _destinations.isNotEmpty && !_isCalculating
                    ? _calculateRoute
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: _destinations.isEmpty || _isCalculating
                      ? Colors.grey[400]
                      : Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isCalculating
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'CALCULAR ROTA (${_destinations.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Cabeçalho da lista de destinos
            if (_destinations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Destinos (${_destinations.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _clearAllDestinations,
                      icon: Icon(Icons.delete_sweep, color: Colors.red, size: 18),
                      label: Text(
                        'Limpar tudo',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // Lista de destinos
            Expanded(
              child: _destinations.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Nenhum destino adicionado',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Adicione destinos acima para calcular a rota',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _destinations.length,
                itemBuilder: (context, index) {
                  final dest = _destinations[index];
                  final isValid = _isValidCoordinate(dest.latitude, dest.longitude);

                  return DestinationItem(
                    destination: dest,
                    index: index + 1,
                    isValid: isValid,
                    onRemove: () => _removeDestination(dest.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPlaceSelected(String address, double lat, double lng, String? label) {
    print('📍 Lugar selecionado via autocomplete:');
    print('   Endereço: $address');
    print('   Coordenadas: $lat, $lng');

    _selectedLat = lat;
    _selectedLng = lng;
    _selectedAddress = address;

    // Preencher label automaticamente se estiver vazio
    if (_labelController.text.isEmpty) {
      // Extrair parte do endereço para o label
      final parts = address.split(',');
      if (parts.isNotEmpty) {
        _labelController.text = parts[0].trim();
      } else if (label != null) {
        _labelController.text = label;
      }
    }

    // Verificar se o endereço tem número
    final hasNumber = RegExp(r'\d+[A-Za-z]?\b').hasMatch(address);
    if (!hasNumber) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️  Endereço sem número. As coordenadas podem não ser exatas.\n'
                  'Para maior precisão, inclua o número do imóvel.',
            ),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.orange[700],
          ),
        );
      });
    }
  }
}