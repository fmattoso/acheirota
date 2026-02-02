import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/navigation_session.dart';

class NavigationService {
  // Stream de posição
  StreamSubscription<Position>? _positionStream;
  Timer? _deviationCheckTimer;
  Timer? _updateTimer;

  // Estado da navegação
  bool _isNavigating = false;
  bool _isPaused = false;
  NavigationSession? _currentSession;
  List<LatLng> _currentRoute = [];

  // Callbacks
  Function(LatLng position, double speed, double? heading)? onPositionUpdate;
  Function(double deviation)? onRouteDeviation;
  Function(NavigationSession session)? onSessionUpdate;
  VoidCallback? onNavigationStarted;
  VoidCallback? onNavigationEnded;

  // Para cálculo de heading
  LatLng? _lastPosition;
  double? _lastKnownHeading;
  List<LatLng> _positionHistory = [];

  // Constantes
  static const double DEVIATION_THRESHOLD = 200.0;
  static const int HISTORY_SIZE = 10;

  // Inicializar serviço
  NavigationService() {
    print('NavigationService inicializado');
  }

  Future<void> startNavigation({
    required List<LatLng> route,
    required double totalDistance,
    required Duration totalDuration,
    required double fuelConsumption,
  }) async {
    try {
      print('Iniciando navegação...');
      print('Rota com ${route.length} pontos');
      print('Distância total: ${totalDistance}m');

      if (route.length < 2) {
        throw Exception('Rota deve ter pelo menos dois pontos');
      }

      // Parar navegação anterior se existir
      await stopNavigation();

      // Limpar histórico
      _positionHistory.clear();
      _lastPosition = null;
      _lastKnownHeading = null;

      // Inicializar sessão
      _currentSession = NavigationSession(
        startTime: DateTime.now(),
        routePoints: route,
        totalDistance: totalDistance,
        totalDuration: totalDuration,
        fuelConsumption: fuelConsumption,
        remainingDistance: totalDistance,
        remainingDuration: totalDuration,
        lastUpdate: DateTime.now(),
      );

      _currentRoute = List.from(route);
      _isNavigating = true;
      _isPaused = false;

      // Notificar início
      if (onNavigationStarted != null) {
        onNavigationStarted!();
      }

      // Iniciar monitoramento
      await _startPositionMonitoring();

      // Iniciar verificações periódicas
      _startPeriodicChecks();

      print('Navegação iniciada com sucesso');

    } catch (e) {
      print('Erro ao iniciar navegação: $e');
      rethrow;
    }
  }

  Future<void> _startPositionMonitoring() async {
    try {
      print('Iniciando monitoramento de posição...');

      // Verificar permissões
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Serviço de localização desativado');
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

      // Configurar stream de posição
      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5, // Atualizar a cada 5 metros
        ),
      ).listen(
            (Position position) => _handlePositionUpdate(position),
        onError: (error) {
          print('Erro no stream de posição: $error');
          _restartPositionMonitoring();
        },
        cancelOnError: false,
      );

      print('Monitoramento de posição iniciado');

    } catch (e) {
      print('Erro ao iniciar monitoramento: $e');
      rethrow;
    }
  }

  void _handlePositionUpdate(Position position) {
    if (!_isNavigating || _isPaused || _currentSession == null) return;

    try {
      final currentLatLng = LatLng(position.latitude, position.longitude);
      final speedKmh = (position.speed * 3.6).abs();

      // Adicionar ao histórico
      _positionHistory.add(currentLatLng);
      if (_positionHistory.length > HISTORY_SIZE) {
        _positionHistory.removeAt(0);
      }

      // Calcular heading
      double? heading = position.heading;

      // Se heading não disponível, calcular com base no movimento
      if ((heading == null || heading == 0.0 || heading.isNaN) && _lastPosition != null) {
        heading = _calculateHeadingFromMovement(_lastPosition!, currentLatLng);
      }

      _lastKnownHeading = heading ?? _lastKnownHeading;
      _lastPosition = currentLatLng;

      // Atualizar sessão
      _updateSession(currentLatLng, speedKmh);

      // Notificar atualização de posição (COM HEADING)
      if (onPositionUpdate != null) {
        onPositionUpdate!(currentLatLng, speedKmh, _lastKnownHeading);
      }

      // Verificar desvio periodicamente (não a cada update para performance)
      final now = DateTime.now();
      if (_currentSession!.lastUpdate.isBefore(now.subtract(Duration(seconds: 5)))) {
        _checkRouteDeviation(currentLatLng);
      }

    } catch (e) {
      print('Erro ao processar atualização de posição: $e');
    }
  }

  double _calculateHeadingFromMovement(LatLng from, LatLng to) {
    try {
      final lat1 = from.latitude * (pi / 180);
      final lon1 = from.longitude * (pi / 180);
      final lat2 = to.latitude * (pi / 180);
      final lon2 = to.longitude * (pi / 180);

      final dLon = lon2 - lon1;

      final y = sin(dLon) * cos(lat2);
      final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

      double heading = atan2(y, x) * (180 / pi);

      // Normalizar para 0-360
      heading = (heading + 360) % 360;

      return heading;
    } catch (e) {
      print('Erro ao calcular heading: $e');
      return 0.0;
    }
  }

  void _updateSession(LatLng currentPosition, double speed) {
    if (_currentSession == null) return;

    try {
      // Adicionar posição
      _currentSession!.addPosition(currentPosition);
      _currentSession!.currentPosition = currentPosition;
      _currentSession!.currentSpeed = speed;

      // Calcular distância percorrida
      double distanceTraveled = _calculateDistanceTraveled();
      _currentSession!.distanceTraveled = distanceTraveled;

      // Calcular distância restante
      double remainingDistance = max(0, _currentSession!.totalDistance - distanceTraveled);
      _currentSession!.remainingDistance = remainingDistance;

      // Calcular tempo restante
      Duration remainingDuration = _calculateRemainingDuration(
        remainingDistance,
        speed,
        _currentSession!.averageSpeed,
      );
      _currentSession!.remainingDuration = remainingDuration;

      // Calcular velocidade média
      _currentSession!.averageSpeed = _calculateAverageSpeed(speed);

      // Atualizar timestamp
      _currentSession!.lastUpdate = DateTime.now();

      // Notificar atualização de sessão
      if (onSessionUpdate != null) {
        onSessionUpdate!(_currentSession!);
      }

    } catch (e) {
      print('Erro ao atualizar sessão: $e');
    }
  }

  double _calculateDistanceTraveled() {
    if (_currentSession == null || _currentSession!.positions.length < 2) return 0;

    try {
      double total = 0;
      final positions = _currentSession!.positions;

      for (int i = 1; i < positions.length; i++) {
        total += Geolocator.distanceBetween(
          positions[i-1].latitude,
          positions[i-1].longitude,
          positions[i].latitude,
          positions[i].longitude,
        );
      }
      return total;
    } catch (e) {
      print('Erro ao calcular distância percorrida: $e');
      return 0;
    }
  }

  double _calculateAverageSpeed(double currentSpeed) {
    if (_currentSession == null || _currentSession!.positions.length < 2) {
      return currentSpeed;
    }

    try {
      final positions = _currentSession!.positions;
      final firstTime = positions.first.timestamp ?? _currentSession!.startTime;
      final lastTime = positions.last.timestamp ?? DateTime.now();

      final totalTime = lastTime.difference(firstTime).inSeconds;
      if (totalTime <= 0) return currentSpeed;

      final totalDistance = _calculateDistanceTraveled();
      final averageSpeedMs = totalDistance / totalTime;

      return averageSpeedMs * 3.6; // Converter para km/h
    } catch (e) {
      print('Erro ao calcular velocidade média: $e');
      return currentSpeed;
    }
  }

  Duration _calculateRemainingDuration(
      double remainingDistance,
      double currentSpeed,
      double averageSpeed,
      ) {
    try {
      if (remainingDistance <= 0) return Duration.zero;

      // Usar velocidade média se disponível, senão usar atual
      double effectiveSpeed = averageSpeed > 0 ? averageSpeed : currentSpeed;
      effectiveSpeed = max(effectiveSpeed, 5.0); // Mínimo 5 km/h

      // Converter km/h para m/s
      double speedMs = effectiveSpeed / 3.6;

      // Calcular tempo em segundos
      int seconds = (remainingDistance / speedMs).round();

      return Duration(seconds: max(seconds, 0));
    } catch (e) {
      print('Erro ao calcular tempo restante: $e');
      return Duration(minutes: 5); // Valor padrão
    }
  }

  void _checkRouteDeviation(LatLng currentPosition) {
    if (_currentRoute.isEmpty || _currentSession == null) return;

    try {
      double minDistance = double.infinity;

      for (final point in _currentRoute) {
        final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          point.latitude,
          point.longitude,
        );
        if (distance < minDistance) {
          minDistance = distance;
        }
      }

      // Verificar desvio
      if (minDistance > DEVIATION_THRESHOLD) {
        _currentSession!.status = NavigationStatus.deviated;

        if (onRouteDeviation != null) {
          onRouteDeviation!(minDistance);
        }
      } else if (_currentSession!.status == NavigationStatus.deviated) {
        _currentSession!.status = NavigationStatus.inProgress;
      }

      if (onSessionUpdate != null) {
        onSessionUpdate!(_currentSession!);
      }

    } catch (e) {
      print('Erro ao verificar desvio: $e');
    }
  }

  void _startPeriodicChecks() {
    _deviationCheckTimer?.cancel();
    _updateTimer?.cancel();

    // Verificar desvio a cada 15 segundos
    _deviationCheckTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      if (!_isNavigating || _isPaused || _lastPosition == null) return;
      _checkRouteDeviation(_lastPosition!);
    });

    // Atualizar UI a cada 3 segundos
    _updateTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (!_isNavigating || _isPaused || _currentSession == null) return;

      if (onSessionUpdate != null) {
        onSessionUpdate!(_currentSession!);
      }
    });
  }

  void _restartPositionMonitoring() {
    Timer(Duration(seconds: 5), () async {
      if (_isNavigating && !_isPaused) {
        try {
          print('Reiniciando monitoramento de posição...');
          await _positionStream?.cancel();
          await _startPositionMonitoring();
        } catch (e) {
          print('Falha ao reiniciar monitoramento: $e');
        }
      }
    });
  }

  void pauseNavigation() {
    if (!_isNavigating || _isPaused) return;

    print('Pausando navegação...');
    _isPaused = true;
    _positionStream?.pause();
    _deviationCheckTimer?.cancel();
    _updateTimer?.cancel();

    if (_currentSession != null) {
      _currentSession!.status = NavigationStatus.paused;
      _currentSession!.lastUpdate = DateTime.now();

      if (onSessionUpdate != null) {
        onSessionUpdate!(_currentSession!);
      }
    }

    print('Navegação pausada');
  }

  void resumeNavigation() {
    if (!_isNavigating || !_isPaused) return;

    print('Retomando navegação...');
    _isPaused = false;
    _positionStream?.resume();
    _startPeriodicChecks();

    if (_currentSession != null) {
      _currentSession!.status = NavigationStatus.inProgress;
      _currentSession!.lastUpdate = DateTime.now();

      if (onSessionUpdate != null) {
        onSessionUpdate!(_currentSession!);
      }
    }

    print('Navegação retomada');
  }

  Future<void> stopNavigation() async {
    print('Parando navegação...');

    _isNavigating = false;
    _isPaused = false;

    // Cancelar timers
    _deviationCheckTimer?.cancel();
    _deviationCheckTimer = null;

    _updateTimer?.cancel();
    _updateTimer = null;

    // Cancelar stream
    await _positionStream?.cancel();
    _positionStream = null;

    // Finalizar sessão
    if (_currentSession != null) {
      _currentSession!.status = NavigationStatus.completed;
      _currentSession!.endTime = DateTime.now();
      _currentSession!.lastUpdate = DateTime.now();

      if (onSessionUpdate != null) {
        onSessionUpdate!(_currentSession!);
      }
    }

    // Limpar estado
    _currentRoute.clear();
    _positionHistory.clear();
    _lastPosition = null;
    _lastKnownHeading = null;

    // Notificar término
    if (onNavigationEnded != null) {
      onNavigationEnded!();
    }

    print('Navegação parada');
  }

  // Getters
  bool get isNavigating => _isNavigating;
  bool get isPaused => _isPaused;
  NavigationSession? get currentSession => _currentSession;
  List<LatLng> get currentRoute => _currentRoute;
  double? get currentHeading => _lastKnownHeading;
}