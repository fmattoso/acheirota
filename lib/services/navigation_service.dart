import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/navigation_session.dart';

class NavigationService {
  final LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 10, // metros
    timeLimit: Duration(seconds: 30),
  );

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<AccelerometerEvent>? _accelerometerStream;
  NavigationSession? _currentSession;
  Timer? _updateTimer;
  bool _isNavigating = false;

  // Callbacks
  Function(LatLng position, double speed)? onPositionUpdate;
  Function(double deviation)? onRouteDeviation;
  Function(NavigationSession session)? onSessionUpdate;
  Function()? onNavigationStarted;
  Function()? onNavigationEnded;

  // Configurações
  double maxAllowedDeviation = 100.0; // metros máximo de desvio
  int updateInterval = 2; // segundos entre atualizações

  // Histórico de posições para cálculos
  List<LatLng> _positionHistory = [];
  List<double> _speedHistory = [];

  Future<void> startNavigation({
    required List<LatLng> route,
    required double totalDistance,
    required int totalDuration,
    required double fuelConsumption,
  }) async {
    if (_isNavigating) {
      await stopNavigation();
    }

    // Criar nova sessão
    _currentSession = NavigationSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      plannedRoute: route,
      totalPlannedDistance: totalDistance,
      totalPlannedDuration: totalDuration,
      fuelConsumption: fuelConsumption,
    );

    _currentSession!.isActive = true;
    _isNavigating = true;

    // Iniciar stream de localização
    await _startPositionTracking();

    // Iniciar detecção de movimento
    await _startMotionDetection();

    // Iniciar timer para atualizações
    _startUpdateTimer();

    // Notificar início
    onNavigationStarted?.call();
    onSessionUpdate?.call(_currentSession!);

    print('🚗 Navegação iniciada');
  }

  Future<void> _startPositionTracking() async {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen((Position position) {
      _handleNewPosition(position);
    });
  }

  Future<void> _startMotionDetection() async {
    _accelerometerStream = accelerometerEvents.listen((AccelerometerEvent event) {
      // Detectar movimento significativo
      final acceleration = sqrt(
          pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2)
      );

      // Se aceleração acima de threshold, está em movimento
      if (acceleration > 2.0 && _currentSession != null && _currentSession!.isPaused) {
        _currentSession!.resume();
      }
    });
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(Duration(seconds: updateInterval), (timer) {
      if (_currentSession != null && _currentSession!.isActive && !_currentSession!.isPaused) {
        _updateNavigationMetrics();
        onSessionUpdate?.call(_currentSession!);
      }
    });
  }

  void _handleNewPosition(Position position) {
    if (_currentSession == null || !_currentSession!.isActive) return;

    final newPosition = LatLng(position.latitude, position.longitude);
    final speed = position.speed * 3.6; // converter m/s para km/h

    // Atualizar sessão
    _currentSession!.updatePosition(newPosition, speed);

    // Adicionar ao histórico
    _positionHistory.add(newPosition);
    _speedHistory.add(speed);

    // Manter histórico limitado (últimos 60 segundos)
    if (_positionHistory.length > 30) { // 30 posições * 2 segundos = 60s
      _positionHistory.removeAt(0);
      _speedHistory.removeAt(0);
    }

    // Verificar desvio da rota
    _checkRouteDeviation(newPosition);

    // Calcular distância percorrida desde última posição
    if (_positionHistory.length > 1) {
      final lastPosition = _positionHistory[_positionHistory.length - 2];
      final distance = _calculateDistance(lastPosition, newPosition);
      _currentSession!.addDistance(distance / 1000); // converter para km
    }

    // Notificar atualização
    onPositionUpdate?.call(newPosition, speed);
    onSessionUpdate?.call(_currentSession!);
  }

  void _checkRouteDeviation(LatLng currentPosition) {
    if (_currentSession == null || _currentSession!.plannedRoute.isEmpty) return;

    // Encontrar ponto mais próximo na rota planejada
    double minDistance = double.infinity;
    LatLng nearestPoint = _currentSession!.plannedRoute.first;

    for (var point in _currentSession!.plannedRoute) {
      final distance = _calculateDistance(currentPosition, point);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = point;
      }
    }

    // Atualizar desvio máximo
    if (minDistance > _currentSession!.maxDeviation) {
      _currentSession!.maxDeviation = minDistance;
    }

    // Se desvio maior que permitido, notificar
    if (minDistance > maxAllowedDeviation) {
      onRouteDeviation?.call(minDistance);

      // Auto-recalcular se desvio muito grande
      if (minDistance > maxAllowedDeviation * 2) {
        _triggerRecalculation();
      }
    }

    print('📍 Distância até rota: ${minDistance.toStringAsFixed(1)}m');
  }

  void _updateNavigationMetrics() {
    if (_currentSession == null || _positionHistory.length < 2) return;

    // Calcular velocidade média recente (últimos 30 segundos)
    if (_speedHistory.isNotEmpty) {
      final recentSpeeds = _speedHistory.length > 10
          ? _speedHistory.sublist(_speedHistory.length - 10)
          : _speedHistory;

      final avgRecentSpeed = recentSpeeds.reduce((a, b) => a + b) / recentSpeeds.length;

      // Estimar tempo restante baseado na velocidade atual
      if (avgRecentSpeed > 0) {
        final remainingDist = _currentSession!.totalPlannedDistance - _currentSession!.totalActualDistance;
        _currentSession!.remainingDistance = remainingDist;
        _currentSession!.remainingTime = (remainingDist / avgRecentSpeed * 60).round();
      }
    }

    // Verificar se chegou ao destino
    _checkDestinationArrival();
  }

  void _checkDestinationArrival() {
    if (_currentSession == null || _positionHistory.isEmpty) return;

    final currentPosition = _positionHistory.last;
    final destinations = _currentSession!.plannedRoute;

    if (_currentSession!.currentDestinationIndex < destinations.length) {
      final target = destinations[_currentSession!.currentDestinationIndex];
      final distanceToTarget = _calculateDistance(currentPosition, target);

      // Se está a menos de 50m do destino, considerar como chegada
      if (distanceToTarget < 50) {
        _currentSession!.currentDestinationIndex++;
        print('✅ Chegou ao destino ${_currentSession!.currentDestinationIndex}');

        // Se chegou ao último destino, finalizar navegação
        if (_currentSession!.currentDestinationIndex >= destinations.length) {
          _completeNavigation();
        }
      }
    }
  }

  void _triggerRecalculation() {
    if (_currentSession == null) return;

    _currentSession!.recalculate();
    print('🔄 Recalculando rota (desvio detectado)');

    // Aqui você chamaria seu DirectionsService para recalcular a rota
    // from currentPosition to remaining destinations
  }

  void _completeNavigation() {
    print('🏁 Navegação concluída!');

    if (_currentSession != null) {
      _currentSession!.end();
      onSessionUpdate?.call(_currentSession!);
      onNavigationEnded?.call();
    }

    stopNavigation();
  }

  Future<void> stopNavigation() async {
    _isNavigating = false;

    // Cancelar streams
    await _positionStream?.cancel();
    await _accelerometerStream?.cancel();
    _positionStream = null;
    _accelerometerStream = null;

    // Cancelar timer
    _updateTimer?.cancel();
    _updateTimer = null;

    // Limpar histórico
    _positionHistory.clear();
    _speedHistory.clear();

    print('🛑 Navegação parada');
  }

  void pauseNavigation() {
    if (_currentSession != null) {
      _currentSession!.pause();
      print('⏸️  Navegação pausada');
    }
  }

  void resumeNavigation() {
    if (_currentSession != null) {
      _currentSession!.resume();
      print('▶️  Navegação retomada');
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  NavigationSession? get currentSession => _currentSession;
  bool get isNavigating => _isNavigating;
}