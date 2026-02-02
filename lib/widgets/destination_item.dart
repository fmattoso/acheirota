import 'package:flutter/material.dart';
import '../models/destination.dart';

class DestinationItem extends StatelessWidget {
  final Destination destination;
  final int index;
  final bool isValid;
  final VoidCallback onRemove;

  const DestinationItem({
    Key? key,
    required this.destination,
    required this.index,
    required this.isValid,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      elevation: 2,
      color: isValid ? Colors.white : Colors.orange[50],
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isValid ? Colors.blue : Colors.orange,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              index.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                destination.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isValid ? Colors.black : Colors.orange[800],
                ),
              ),
            ),
            if (!isValid)
              Icon(Icons.warning, color: Colors.orange, size: 16),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              destination.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13),
            ),
            if (!isValid)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '⚠️ Coordenadas inválidas - Remova e adicione novamente',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (destination.stopDuration > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 14, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      '${destination.stopDuration} min de parada',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: onRemove,
          tooltip: 'Remover destino',
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}