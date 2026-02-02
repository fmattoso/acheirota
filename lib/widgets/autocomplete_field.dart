import 'package:flutter/material.dart';
import '../services/places_service.dart';

class AutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final PlacesService placesService;
  final Function(String, double, double, String?) onPlaceSelected;
  final String hintText;
  final String labelText;

  const AutocompleteField({
    Key? key,
    required this.controller,
    required this.placesService,
    required this.onPlaceSelected,
    this.hintText = 'Digite um endereço...',
    this.labelText = 'Endereço',
  }) : super(key: key);

  @override
  _AutocompleteFieldState createState() => _AutocompleteFieldState();
}

class _AutocompleteFieldState extends State<AutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && widget.controller.text.isNotEmpty) {
      _showSuggestions = true;
      _createOverlay();
    } else if (!_focusNode.hasFocus) {
      _showSuggestions = false;
      _removeOverlay();
    }
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();
    if (query.length > 2 && _focusNode.hasFocus) {
      _fetchSuggestions();
      _showSuggestions = true;
      _createOverlay();
    } else {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
      _removeOverlay();
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

      _createOverlay();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showSuggestions = false;
      });
      _removeOverlay();
    }
  }

  void _createOverlay() {
    if (!_showSuggestions || _suggestions.isEmpty) {
      _removeOverlay();
      return;
    }

    // Remover overlay existente
    _removeOverlay();

    // Criar novo overlay
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildSuggestionsOverlay(),
    );

    // Adicionar ao overlay
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  Widget _buildSuggestionsOverlay() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return Container();

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return Positioned(
      left: offset.dx,
      top: offset.dy + size.height + 4,
      width: size.width,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: BoxConstraints(maxHeight: 300),
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
          child: _isLoading
              ? _buildLoading()
              : _suggestions.isEmpty
              ? _buildNoResults()
              : _buildSuggestionsList(),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return _buildSuggestionItem(suggestion, index);
      },
    );
  }

  Widget _buildSuggestionItem(Map<String, dynamic> suggestion, int index) {
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
  }

  Widget _buildLoading() {
    return Container(
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
    );
  }

  Widget _buildNoResults() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Text(
        'Nenhum endereço encontrado',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    widget.controller.text = suggestion['description'];
    _focusNode.unfocus();

    setState(() {
      _suggestions.clear();
      _showSuggestions = false;
    });

    _removeOverlay();

    // Buscar detalhes para obter coordenadas
    final details = await widget.placesService.getPlaceDetails(suggestion['placeId']);
    if (details != null) {
      widget.onPlaceSelected(
        details['address'],
        details['latitude'],
        details['longitude'],
        details['name'],
      );
    } else {
      // Usar apenas o texto se não conseguir detalhes
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
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, size: 20),
              onPressed: () {
                widget.controller.clear();
                setState(() {
                  _suggestions.clear();
                  _showSuggestions = false;
                });
                _removeOverlay();
              },
            )
                : null,
          ),
        ),
      ],
    );
  }
}