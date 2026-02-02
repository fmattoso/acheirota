import 'package:flutter/material.dart';
import 'dart:async';
import '../services/geocoding_autocomplete_service.dart';

class ImprovedAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final GeocodingAutocompleteService autocompleteService;
  final Function(String, double, double, String?) onPlaceSelected;
  final String hintText;
  final String labelText;

  const ImprovedAutocompleteField({
    Key? key,
    required this.controller,
    required this.autocompleteService,
    required this.onPlaceSelected,
    this.hintText = 'Digite um endereço com número...',
    this.labelText = 'Endereço *',
  }) : super(key: key);

  @override
  _ImprovedAutocompleteFieldState createState() => _ImprovedAutocompleteFieldState();
}

class _ImprovedAutocompleteFieldState extends State<ImprovedAutocompleteField> {
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      setState(() {
        _suggestions.clear();
      });
    }
  }

  void _onTextChanged() {
    if (_debounceTimer != null && _debounceTimer!.isActive) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(Duration(milliseconds: 800), () async {
      final query = widget.controller.text.trim();

      if (query.length < 3) {
        setState(() {
          _suggestions.clear();
          _isSearching = false;
        });
        return;
      }

      setState(() => _isSearching = true);

      final results = await widget.autocompleteService.getSuggestions(query);

      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final address = suggestion['address'];
    final lat = suggestion['latitude'];
    final lng = suggestion['longitude'];

    print('📍 Sugestão selecionada:');
    print('   Endereço: $address');
    print('   Rua: ${suggestion['route']}');
    print('   Número: ${suggestion['streetNumber']}');
    print('   Coordenadas: $lat, $lng');

    widget.controller.text = address;
    _focusNode.unfocus();

    setState(() {
      _suggestions.clear();
    });

    widget.onPlaceSelected(
      address,
      lat,
      lng,
      suggestion['mainText'],
    );
  }

  Widget _buildSuggestionItem(Map<String, dynamic> suggestion, int index) {
    final hasNumber = suggestion['hasNumber'];
    final accuracy = suggestion['accuracy'] as int;
    final accuracyDesc = suggestion['accuracyDescription'] as String;

    // Determinar cor baseado na precisão
    Color accuracyColor;
    if (accuracy >= 8) {
      accuracyColor = Colors.green;
    } else if (accuracy >= 5) {
      accuracyColor = Colors.orange;
    } else {
      accuracyColor = Colors.red;
    }

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accuracyColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accuracyColor.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(
            '${accuracy}/10',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: accuracyColor,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              suggestion['mainText'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasNumber ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasNumber)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Text(
                'Nº ${suggestion['number']}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion['secondaryText'],
            style: TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            accuracyDesc,
            style: TextStyle(
              fontSize: 10,
              color: accuracyColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      dense: true,
      onTap: () => _selectSuggestion(suggestion),
    );
  }

  bool _isExactMatch(Map<String, dynamic> suggestion) {
    final input = widget.controller.text.toLowerCase();
    final address = suggestion['address'].toLowerCase();
    final route = suggestion['route'].toString().toLowerCase();

    // Verificar se o input contém número
    final inputHasNumber = RegExp(r'\d').hasMatch(input);
    final suggestionHasNumber = suggestion['streetNumber'].toString().isNotEmpty;

    // Se o input tem número e a sugestão também tem, é um bom match
    if (inputHasNumber && suggestionHasNumber) {
      // Verificar se o número do input está na sugestão
      final inputNumberMatch = RegExp(r'(\d+)').firstMatch(input);
      if (inputNumberMatch != null) {
        final inputNumber = inputNumberMatch.group(1);
        return suggestion['address'].contains(inputNumber!);
      }
    }

    return address.contains(input) || route.contains(input);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: Icon(Icons.search, color: Colors.blue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            suffixIcon: _isSearching
                ? Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : widget.controller.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, size: 20),
              onPressed: () {
                widget.controller.clear();
                setState(() {
                  _suggestions.clear();
                });
              },
            )
                : null,
            helperText: 'Inclua o número para maior precisão',
            helperStyle: TextStyle(fontSize: 12),
          ),
        ),

        // Dica sobre formato
        Padding(
          padding: const EdgeInsets.only(top: 4.0, left: 4.0),
          child: Text(
            'Exemplo: "Avenida Paulista, 1000, São Paulo"',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ),

        // Sugestões
        if (_suggestions.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 8),
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
            constraints: BoxConstraints(maxHeight: 250),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Sugestões (${_suggestions.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),

                // Lista de sugestões
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return _buildSuggestionItem(suggestion, index);
                    },
                  ),
                ),

                // Rodapé
                if (_suggestions.any((s) => s['streetNumber'].toString().isEmpty))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Text(
                      '💡 Inclua o número para maior precisão nas coordenadas',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}