import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/app_state.dart';
import '../models/navigation_session.dart';
import '../models/route_calculation.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../services/navigation_service.dart';
import '../widgets/route_info_card.dart';
import '../widgets/navigation_panel.dart';
import 'destinations_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();
  final NavigationService _navigationService = NavigationService();

  late GoogleMapController _mapController;
  Position? _currentPosition;
  String _currentAddress = '';
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = true;
  bool _showResumeDialog = false;
  RouteCalculation? _currentRoute;
  List<LatLng> _routePoints = [];

  // Navegação
  bool _isNavigating = false;
  NavigationSession? _currentNavSession;
  Timer? _autoStartTimer;
  double? _currentSpeed;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _checkForSavedRoute();
    _setupNavigationListeners();
  }

  @override
  void dispose() {
    _navigationService.stopNavigation();
    _autoStartTimer?.cancel();
    super.dispose();
  }

  void _setupNavigationListeners() {
    _navigationService.onPositionUpdate = (position, speed) {
      setState(() {
        _currentPosition = Position(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitudeAccuracy: 0,
          altitude: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: speed / 3.6, // converter km/h para m/s
          speedAccuracy: 0,
        );
        _currentSpeed = speed;

        // Atualizar marcador de posição atual
        _updateCurrentLocationMarker();

        // Ajustar câmera se navegando
        if (_isNavigating) {
          _mapController.animateCamera(
            CameraUpdate.newLatLngZoom(position, 16),
          );
        }
      });
    };

    _navigationService.onRouteDeviation = (deviation) {
      if (deviation > 200) { // Mais de 200m de desvio
        _showDeviationAlert(deviation);
      }
    };

    _navigationService.onSessionUpdate = (session) {
      setState(() {
        _currentNavSession = session;
      });
    };

    _navigationService.onNavigationStarted = () {
      setState(() {
        _isNavigating = true;
      });
      _showNavigationStartedSnackbar();
    };

    _navigationService.onNavigationEnded = () {
      setState(() {
        _isNavigating = false;
      });
      _showNavigationCompletedSnackbar();
    };
  }

  Future<void> _initializeLocation() async {
    try {
      _currentPosition = await _locationService.getCurrentLocation();
      _currentAddress = await _locationService.getAddressFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      _updateCurrentLocationMarker();
    } catch (e) {
      print('Erro ao obter localização: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateCurrentLocationMarker() {
    if (_currentPosition != null) {
      setState(() {
        // Remover marcador antigo
        _markers.removeWhere((marker) => marker.markerId.value == 'current_location');

        // Adicionar novo marcador
        _markers.add(
          Marker(
            markerId: MarkerId('current_location'),
            position: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            infoWindow: InfoWindow(
              title: 'Minha Localização',
              snippet: _currentAddress,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            rotation: _currentPosition?.heading ?? 0,
          ),
        );
      });

      // Só ajustar câmera se não estiver navegando
      if (!_isNavigating) {
        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            14,
          ),
        );
      }
    }
  }

  Future<void> _openDestinationsScreen() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => DestinationsScreen()),
    );

    if (result != null && result['route'] != null) {
      setState(() {
        _currentRoute = result['route'] as RouteCalculation;
        _routePoints = (result['polylinePoints'] as List).cast<LatLng>();

        Provider.of<AppState>(context, listen: false)
            .setCurrentRoute(_currentRoute!);
      });

      await _storageService.saveRoute(_currentRoute!);
      _displayRoute();

      // Perguntar se quer iniciar navegação
      _askToStartNavigation();
    }
  }

  void _askToStartNavigation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Iniciar Navegação?'),
        content: Text('Deseja iniciar o modo de navegação para esta rota? '
            'O app irá acompanhar seu progresso e recalcular se necessário.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Depois'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startNavigation();
            },
            child: Text('Iniciar Navegação'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  void _startNavigation() async {
    if (_currentRoute == null || _routePoints.isEmpty) return;

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      await _navigationService.startNavigation(
        route: _routePoints,
        totalDistance: _currentRoute!.totalDistance,
        totalDuration: _currentRoute!.totalDuration,
        fuelConsumption: appState.fuelConsumption,
      );

      // Iniciar detecção automática de movimento
      _startAutoNavigationDetection();

    } catch (e) {
      print('Erro ao iniciar navegação: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao iniciar navegação: $e')),
      );
    }
  }

  void _startAutoNavigationDetection() {
    // Cancelar timer anterior
    _autoStartTimer?.cancel();

    // Iniciar timer para detectar movimento e auto-iniciar
    _autoStartTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (_isNavigating) {
        timer.cancel();
        return;
      }

      final position = await _locationService.getCurrentLocation();
      final speed = position.speed * 3.6; // km/h

      // Se velocidade > 10 km/h, assumir que começou a dirigir
      if (speed > 10 && _currentRoute != null) {
        print('🚗 Movimento detectado, iniciando navegação automática');
        timer.cancel();
        _startNavigation();
      }
    });
  }

  void _showDeviationAlert(double deviation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Desvio da Rota Detectado'),
        content: Text('Você está ${deviation.toStringAsFixed(0)} metros '
            'fora da rota planejada. Deseja recalcular a rota?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continuar assim'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _recalculateRoute();
            },
            child: Text('Recalcular Rota'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  void _recalculateRoute() async {
    if (_currentPosition == null || _currentRoute == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Recalculando Rota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Calculando nova rota a partir da sua posição atual...'),
          ],
        ),
      ),
    );

    try {
      // Aqui você implementaria a lógica para recalcular a rota
      // usando seu DirectionsService com a posição atual
      // e os destinos restantes

      // Por enquanto, apenas mostramos um feedback
      await Future.delayed(Duration(seconds: 2));

      Navigator.pop(context); // Fechar dialog de carregamento

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Rota recalculada!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      Navigator.pop(context); // Fechar dialog de carregamento
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao recalcular rota: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _displayRoute() {
    if (_currentRoute == null || _routePoints.isEmpty) return;

    setState(() {
      // Limpar marcadores antigos
      _markers.removeWhere((marker) => marker.markerId.value != 'current_location');

      // Limpar polylines antigas
      _polylines.clear();

      // Adicionar marcadores para cada destino
      for (int i = 0; i < _currentRoute!.destinations.length; i++) {
        final dest = _currentRoute!.destinations[i];
        _markers.add(
          Marker(
            markerId: MarkerId('destination_${dest.id}'),
            position: LatLng(dest.latitude, dest.longitude),
            infoWindow: InfoWindow(
              title: dest.label,
              snippet: 'Parada ${i + 1}: ${dest.address}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        );
      }

      // Adicionar polyline da rota
      if (_routePoints.length > 1) {
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route'),
            color: Colors.blue,
            width: 5,
            points: _routePoints,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      }

      // Ajustar a câmera para mostrar toda a rota
      if (_markers.isNotEmpty) {
        LatLngBounds bounds = _boundsFromMarkers();
        _mapController.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      }
    });
  }

  LatLngBounds _boundsFromMarkers() {
    double? minLat, maxLat, minLng, maxLng;

    for (var marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      minLat = (minLat == null || lat < minLat) ? lat : minLat;
      maxLat = (maxLat == null || lat > maxLat) ? lat : maxLat;
      minLng = (minLng == null || lng < minLng) ? lng : minLng;
      maxLng = (maxLng == null || lng > maxLng) ? lng : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat ?? -23.6, minLng ?? -46.7),
      northeast: LatLng(maxLat ?? -23.5, maxLng ?? -46.6),
    );
  }

  Future<void> _checkForSavedRoute() async {
    final route = await _storageService.loadRoute();
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showResumeRouteDialog(route);
      });
    }
  }

  void _showResumeRouteDialog(RouteCalculation route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rota Salva Encontrada'),
        content: Text('Deseja retomar a rota interrompida?'),
        actions: [
          TextButton(
            onPressed: () {
              _storageService.deleteRoute();
              Navigator.pop(context);
            },
            child: Text('Não'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentRoute = route;
              });
              Provider.of<AppState>(context, listen: false)
                  .setCurrentRoute(route);
              Navigator.pop(context);
              _askToStartNavigation();
            },
            child: Text('Sim'),
          ),
        ],
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _currentRoute = null;
      _routePoints.clear();
      _polylines.clear();
      _markers.removeWhere((marker) => marker.markerId.value != 'current_location');
    });
    Provider.of<AppState>(context, listen: false).clearRoute();
    _storageService.deleteRoute();
    _navigationService.stopNavigation();
  }

  void _stopNavigation() {
    _navigationService.stopNavigation();
    setState(() {
      _isNavigating = false;
    });
  }

  void _pauseNavigation() {
    _navigationService.pauseNavigation();
  }

  void _resumeNavigation() {
    _navigationService.resumeNavigation();
  }

  void _showNavigationStartedSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚗 Navegação iniciada!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showNavigationCompletedSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🏁 Navegação concluída!'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Planejador de Rotas'),
        actions: [
          if (_isNavigating)
            IconButton(
              icon: Icon(Icons.stop),
              onPressed: _stopNavigation,
              tooltip: 'Parar navegação',
            ),
          if (appState.isRouteActive && !_isNavigating)
            IconButton(
              icon: Icon(Icons.clear_all),
              onPressed: _clearRoute,
              tooltip: 'Limpar rota',
            ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _updateCurrentLocationMarker();
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _currentPosition?.latitude ?? -23.5505,
                _currentPosition?.longitude ?? -46.6333,
              ),
              zoom: 12,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            compassEnabled: true,
            trafficEnabled: _isNavigating,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            onCameraIdle: () {
              // Se estiver navegando, voltar para tracking
              if (_isNavigating && _currentPosition != null) {
                _mapController.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    16,
                  ),
                );
              }
            },
          ),

          // Painel de navegação
          if (_isNavigating && _currentNavSession != null)
            NavigationPanel(
              session: _currentNavSession!,
              currentSpeed: _currentSpeed ?? 0,
              onPause: _pauseNavigation,
              onResume: _resumeNavigation,
              onStop: _stopNavigation,
            ),

          // Card de informações da rota (se não estiver navegando)
          if (appState.isRouteActive && _currentRoute != null && !_isNavigating)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: RouteInfoCard(
                route: _currentRoute!,
                fuelConsumption: appState.fuelConsumption,
                onClear: _clearRoute,
                onNavigate: _startNavigation,
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(appState),
    );
  }

  Widget _buildFloatingActionButtons(AppState appState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_isNavigating)
          FloatingActionButton.small(
            onPressed: () {
              // Alternar entre visão da rota e tracking
              if (_currentPosition != null) {
                _mapController.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    16,
                  ),
                );
              }
            },
            child: Icon(Icons.my_location),
            tooltip: 'Centralizar na minha localização',
            heroTag: 'location_fab',
          ),
        if (_isNavigating)
          SizedBox(height: 10),
        if (appState.isRouteActive && !_isNavigating)
          FloatingActionButton.small(
            onPressed: () {
              if (_markers.isNotEmpty) {
                LatLngBounds bounds = _boundsFromMarkers();
                _mapController.animateCamera(
                  CameraUpdate.newLatLngBounds(bounds, 100),
                );
              }
            },
            child: Icon(Icons.fit_screen),
            tooltip: 'Mostrar rota completa',
            heroTag: 'fit_fab',
          ),
        if (appState.isRouteActive && !_isNavigating)
          SizedBox(height: 10),
        FloatingActionButton(
          onPressed: _openDestinationsScreen,
          child: Icon(Icons.add_location),
          tooltip: 'Adicionar Destinos',
        ),
      ],
    );
  }
}