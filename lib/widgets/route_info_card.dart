import 'package:flutter/material.dart';
import '../models/route_calculation.dart';

class RouteInfoCard extends StatelessWidget {
  final RouteCalculation route;
  final double fuelConsumption;
  final VoidCallback onClear;
  final VoidCallback onNavigate;

  const RouteInfoCard({
    Key? key,
    required this.route,
    required this.fuelConsumption,
    required this.onClear,
    required this.onNavigate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalKm = route.totalDistance / 1000;
    final double fuelNeeded = fuelConsumption > 0 ? totalKm / fuelConsumption : 0;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rota Calculada',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey),
                  onPressed: onClear,
                  tooltip: 'Limpar rota',
                ),
              ],
            ),
            SizedBox(height: 12),

            // Informações da rota
            _buildRouteInfo(totalKm, fuelNeeded),
            SizedBox(height: 16),

            // Botões de ação
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo(double totalKm, double fuelNeeded) {
    return Column(
      children: [
        // Distância e tempo
        Row(
          children: [
            _buildInfoChip(
              icon: Icons.linear_scale,
              label: 'Distância',
              value: '${(route.totalDistance / 1000).toStringAsFixed(1)} km',
              color: Colors.blue,
            ),
            SizedBox(width: 12),
            _buildInfoChip(
              icon: Icons.timer,
              label: 'Tempo Estimado',
              value: _formatDuration(route.totalDuration),
              color: Colors.green,
            ),
          ],
        ),
        SizedBox(height: 12),

        // Destinos
        if (route.destinations.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Destinos:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              ...route.destinations.asMap().entries.map((entry) {
                final index = entry.key;
                final destination = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: index == 0 ? Colors.green : Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              destination.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              destination.address,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),

        // Consumo de combustível (se configurado)
        if (fuelConsumption > 0)
          Column(
            children: [
              SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.local_gas_station,
                    label: 'Combustível Necessário',
                    value: '${fuelNeeded.toStringAsFixed(1)} L',
                    color: Colors.orange,
                  ),
                  SizedBox(width: 12),
                  _buildInfoChip(
                    icon: Icons.ev_station,
                    label: 'Consumo',
                    value: '${fuelConsumption.toStringAsFixed(1)} km/L',
                    color: Colors.teal,
                  ),
                ],
              ),
            ],
          ),

        // Informações adicionais
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Esta rota inclui ${route.destinations.length} destino(s) '
                      'com um tempo total estimado de ${_formatDuration(route.totalDuration)}.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.clear, size: 20, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  'Limpar Rota',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onNavigate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.navigation, size: 20),
                SizedBox(width: 8),
                Text('Iniciar Navegação'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes} min';
    }
  }
}