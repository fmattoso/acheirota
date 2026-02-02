import 'package:flutter/material.dart';
import '../services/places_service.dart';

class SimpleAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final PlacesService placesService;
  final Function(String, double, double, String?) onPlaceSelected;
  final String hintText;
  final String labelText;

  const SimpleAutocompleteField({
    Key? key,
    required this.controller,
    required this.placesService,
    required this.onPlaceSelected,
    this.hintText = 'Digite um endereço...',
    this.labelText = 'Endereço',
  }) : super(key: key);

  @override
  _SimpleAutocompleteFieldState createState() => _SimpleAutocompleteFieldState();
}

class _SimpleAutocompleteFieldState extends State<SimpleAutocompleteField> {
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();
    if (query.length > 2) {
      _fetchSuggestions();
      _showSuggestions = true;
    } else {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
    }
  }

  Future<void> _fetchSuggestions() async {
    final query = widget.controller.text.trim();
    if (query.length < 3) {
      setState(() {
        _suggestions.clear();
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final suggestions = await widget.placesService.getAutocompleteSuggestions(query);

      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
        _showSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showSuggestions = false;
      });
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    widget.controller.text = suggestion['description'];

    setState(() {
      _suggestions.clear();
      _showSuggestions = false;
    });

    // Buscar detalhes para obter coordenadas
    try {
      final details = await widget.placesService.getPlaceDetails(suggestion['placeId']);
      if (details != null) {
        widget.onPlaceSelected(
          details['address'],
          details['latitude'],
          details['longitude'],
          details['name'],
        );
      } else {
        widget.onPlaceSelected(
          suggestion['description'],
          0,
          0,
          null,
        );
      }
    } catch (e) {
      print('Erro ao obter detalhes: $e');
      widget.onPlaceSelected(
        suggestion['description'],
        0,
        0,
        null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: Icon(Icons.search, color: Colors.blue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, size: 20),
              onPressed: () {
                widget.controller.clear();
                setState(() {
                  _suggestions.clear();
                  _showSuggestions = false;
                });
              },
            )
                : null,
          ),
        ),

        // Sugestões abaixo do campo
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 4),
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
            child: _isLoading
                ? Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Buscando endereços...'),
                ],
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  leading: Icon(Icons.location_on, color: Colors.blue, size: 20),
                  title: Text(
                    suggestion['mainText'] ?? suggestion['description'],
                    style: TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: suggestion['secondaryText']?.isNotEmpty == true
                      ? Text(
                    suggestion['secondaryText'],
                    style: TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                      : null,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}