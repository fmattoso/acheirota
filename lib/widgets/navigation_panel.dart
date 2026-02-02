import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0) {
      return '${hours}h ${remainingMinutes}min';
    }
    return '${remainingMinutes}min';
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final remainingDist = session.remainingDistance ?? 0;
    final remainingTime = session.remainingTime ?? 0;
    final progress = session.totalActualDistance / session.totalPlannedDistance;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      right: 8,
      child: Card(
        elevation: 8,
        color: Colors.white.withOpacity(0.95),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Icon(Icons.directions_car, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'NAVEGAÇÃO ATIVA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  Spacer(),
                  _buildStatusIndicator(),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, size: 18),
                    onPressed: onStop,
                    tooltip: 'Parar navegação',
                  ),
                ],
              ),

              Divider(height: 16),

              // Informações principais
              Row(
                children: [
                  // Velocidade atual
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${currentSpeed.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _getSpeedColor(currentSpeed),
                          ),
                        ),
                        Text(
                          'km/h',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Distância e tempo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.flag, size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              '${remainingDist.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.timer, size: 14, color: Colors.orange),
                            SizedBox(width: 4),
                            Text(
                              _formatDuration(remainingTime),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Barra de progresso
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progresso',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    color: Colors.blue,
                    minHeight: 6,
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${session.totalActualDistance.toStringAsFixed(1)} km',
                        style: TextStyle(fontSize: 10),
                      ),
                      Text(
                        '${session.totalPlannedDistance.toStringAsFixed(1)} km',
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Métricas secundárias
              Row(
                children: [
                  _buildMetricItem(
                    icon: Icons.local_gas_station,
                    value: '${session.fuelUsed.toStringAsFixed(1)} L',
                    label: 'Combustível',
                  ),
                  Spacer(),
                  _buildMetricItem(
                    icon: Icons.speed,
                    value: '${session.averageSpeed.toStringAsFixed(0)} km/h',
                    label: 'Média',
                  ),
                  Spacer(),
                  _buildMetricItem(
                    icon: Icons.timer,
                    value: _formatTime(session.startedAt),
                    label: 'Início',
                  ),
                  Spacer(),
                  if (session.recalculationCount > 0)
                    _buildMetricItem(
                      icon: Icons.refresh,
                      value: '${session.recalculationCount}x',
                      label: 'Recalculos',
                      color: Colors.orange,
                    ),
                ],
              ),

              // Botões de controle
              if (session.isPaused)
                SizedBox(height: 12),
              if (session.isPaused)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onResume,
                    icon: Icon(Icons.play_arrow),
                    label: Text('RETOMAR NAVEGAÇÃO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color color;
    IconData icon;
    String tooltip;

    if (session.isPaused) {
      color = Colors.orange;
      icon = Icons.pause;
      tooltip = 'Pausado';
    } else {
      color = Colors.green;
      icon = Icons.play_arrow;
      tooltip = 'Em andamento';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String value,
    required String label,
    Color color = Colors.blue,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getSpeedColor(double speed) {
    if (speed < 40) return Colors.blue;
    if (speed < 80) return Colors.green;
    if (speed < 100) return Colors.orange;
    return Colors.red;
  }
}