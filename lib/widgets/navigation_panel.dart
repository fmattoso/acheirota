import 'package:flutter/material.dart';
import '../models/navigation_session.dart';

class NavigationPanel extends StatelessWidget {
  final NavigationSession session;
  final double currentSpeed;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const NavigationPanel({
    Key? key,
    required this.session,
    required this.currentSpeed,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isPaused = session.status == NavigationStatus.paused;

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho com status
              _buildHeader(isPaused),
              SizedBox(height: 16),

              // Informações da navegação
              _buildNavigationInfo(),
              SizedBox(height: 16),

              // Controles de navegação
              _buildControls(isPaused),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isPaused) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.navigation,
              color: isPaused ? Colors.orange : Colors.blue,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              isPaused ? 'Navegação Pausada' : 'Em Navegação',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isPaused ? Colors.orange : Colors.blue,
              ),
            ),
          ],
        ),
        // Heading atual
        if (session.currentHeading != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.explore,
                  size: 16,
                  color: Colors.blue,
                ),
                SizedBox(width: 4),
                Text(
                  session.formattedCurrentHeading,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNavigationInfo() {
    return Column(
      children: [
        // Velocidade atual
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoItem(
              icon: Icons.speed,
              label: 'Velocidade',
              value: '${currentSpeed.round()} km/h',
              color: Colors.green,
            ),
            _buildInfoItem(
              icon: Icons.timelapse,
              label: 'Tempo Restante',
              value: session.formattedRemainingTime,
              color: Colors.blue,
            ),
          ],
        ),
        SizedBox(height: 12),

        // Distância
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoItem(
              icon: Icons.linear_scale,
              label: 'Distância Restante',
              value: session.formattedRemainingDistance,
              color: Colors.orange,
            ),
            _buildInfoItem(
              icon: Icons.flag,
              label: 'Percorrido',
              value: '${(session.distanceTraveled / 1000).toStringAsFixed(1)} km',
              color: Colors.purple,
            ),
          ],
        ),
        SizedBox(height: 12),

        // Progresso
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progresso',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${(session.progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            LinearProgressIndicator(
              value: session.progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                session.progress > 0.8 ? Colors.green : Colors.blue,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),

        // Combustível (se disponível)
        if (session.fuelConsumption > 0)
          Column(
            children: [
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoItem(
                    icon: Icons.local_gas_station,
                    label: 'Combustível',
                    value: '${session.fuelUsed.toStringAsFixed(1)} L',
                    color: Colors.red,
                  ),
                  _buildInfoItem(
                    icon: Icons.ev_station,
                    label: 'Consumo',
                    value: '${session.fuelConsumption.toStringAsFixed(1)} km/L',
                    color: Colors.teal,
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(bool isPaused) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Botão Parar
        ElevatedButton(
          onPressed: onStop,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stop, size: 20),
              SizedBox(width: 8),
              Text('Parar'),
            ],
          ),
        ),

        // Botão Pausar/Retomar
        ElevatedButton(
          onPressed: isPaused ? onResume : onPause,
          style: ElevatedButton.styleFrom(
            backgroundColor: isPaused ? Colors.green : Colors.orange,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 20),
              SizedBox(width: 8),
              Text(isPaused ? 'Retomar' : 'Pausar'),
            ],
          ),
        ),
      ],
    );
  }
}