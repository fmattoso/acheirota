import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/route_calculation.dart';

class RouteInfoCard extends StatelessWidget {
  final RouteCalculation route;
  final double fuelConsumption;
  final VoidCallback? onClear;
  final VoidCallback? onNavigate; // ADICIONE ESTA LINHA

  const RouteInfoCard({
    Key? key,
    required this.route,
    required this.fuelConsumption,
    this.onClear,
    this.onNavigate, // ADICIONE ESTA LINHA
  }) : super(key: key);

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0) {
      return '${hours}h ${remainingMinutes}min';
    }
    return '${remainingMinutes}min';
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yy HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rota Calculada',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    icon: Icon(Icons.close, size: 20),
                    onPressed: onClear,
                    tooltip: 'Limpar rota',
                  ),
              ],
            ),
            SizedBox(height: 12),

            // Informações principais
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  icon: Icons.add_road,
                  label: 'Distância',
                  value: '${route.totalDistance.toStringAsFixed(1)} km',
                  color: Colors.green,
                ),
                _buildInfoItem(
                  icon: Icons.timer,
                  label: 'Tempo Total',
                  value: _formatDuration(route.totalDuration),
                  color: Colors.orange,
                ),
                _buildInfoItem(
                  icon: Icons.local_gas_station,
                  label: 'Combustível',
                  value: '${route.fuelRequired.toStringAsFixed(1)} L',
                  color: Colors.red,
                ),
              ],
            ),

            SizedBox(height: 12),

            // Botão de navegação (se fornecido)
            if (onNavigate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onNavigate,
                    icon: Icon(Icons.directions_car, size: 20),
                    label: Text('INICIAR NAVEGAÇÃO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),

            // Informações secundárias
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '${route.destinations.length} paradas',
                  style: TextStyle(fontSize: 14),
                ),
                Spacer(),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  _formatDateTime(route.calculatedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Consumo de combustível
            Row(
              children: [
                Icon(Icons.info, size: 16, color: Colors.blueGrey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Consumo: ${fuelConsumption.toStringAsFixed(1)} km/L',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}