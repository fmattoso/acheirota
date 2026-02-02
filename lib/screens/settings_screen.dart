import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _fuelController = TextEditingController();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final consumption = await _storageService.loadFuelConsumption();
    _fuelController.text = consumption.toStringAsFixed(1);
  }

  Future<void> _saveSettings() async {
    final consumption = double.tryParse(_fuelController.text) ?? 10.0;

    Provider.of<AppState>(context, listen: false)
        .setFuelConsumption(consumption);

    await _storageService.saveFuelConsumption(consumption);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Configurações salvas!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configurações'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurações do Veículo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _fuelController,
              decoration: InputDecoration(
                labelText: 'Consumo de Combustível (km/l)',
                hintText: 'Ex: 10.5',
                border: OutlineInputBorder(),
                suffixText: 'km/l',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 30),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                child: Text('SALVAR CONFIGURAÇÕES'),
              ),
            ),
            SizedBox(height: 40),
            Text(
              'Informações',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'O aplicativo calcula a rota mais eficiente considerando '
                  'todos os destinos e tempos de parada. '
                  'As rotas são salvas automaticamente para retomada posterior.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}