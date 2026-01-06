import 'dart:convert';

import 'package:http/http.dart' as http;

class PlaceSuggestion {
  final String description;
  final String placeId;

  PlaceSuggestion({required this.description, required this.placeId});
}

class PlaceDetailsResult {
  final String formattedAddress;
  final double lat;
  final double lng;

  PlaceDetailsResult({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });
}

/// Serviço simples para buscar sugestões de endereços e detalhes usando
/// a API do Google Places.
class PlacesAutocompleteService {
  // ATENCAO: idealmente essa chave viria de uma config/segredo.
  // Aqui usamos a mesma chave do AndroidManifest para facilitar.
  static const String _apiKey = 'AIzaSyDkaBMVHPdTITYUm-XOpDZ9n0nWU-8kAoA';

  static const String _autocompleteEndpoint =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String _detailsEndpoint =
      'https://maps.googleapis.com/maps/api/place/details/json';

  /// Retorna uma lista de sugestoes a partir de um texto digitado.
  static Future<List<PlaceSuggestion>> fetchSuggestions(String input) async {
    if (input.trim().isEmpty) return [];

    final uri = Uri.parse(_autocompleteEndpoint).replace(
      queryParameters: {
        'input': input,
        'types': 'geocode',
        'language': 'pt',
        // Limita inicialmente para Mocambique; ajuste se precisar de outros paises.
        'components': 'country:MZ',
        'key': _apiKey,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return [];
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      return [];
    }

    final predictions = (data['predictions'] as List?) ?? [];
    return predictions
        .map(
          (p) => PlaceSuggestion(
            description: (p['description'] as String?) ?? '',
            placeId: (p['place_id'] as String?) ?? '',
          ),
        )
        .where((p) => p.description.isNotEmpty && p.placeId.isNotEmpty)
        .toList();
  }

  /// Dado um placeId, busca coordenadas e endereco formatado.
  static Future<PlaceDetailsResult?> fetchPlaceDetails(String placeId) async {
    if (placeId.isEmpty) return null;

    final uri = Uri.parse(_detailsEndpoint).replace(
      queryParameters: {
        'place_id': placeId,
        'fields': 'geometry,formatted_address',
        'language': 'pt',
        'key': _apiKey,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      return null;
    }

    final result = data['result'] as Map<String, dynamic>;
    final formattedAddress = (result['formatted_address'] as String?) ?? '';

    final geometry = result['geometry'] as Map<String, dynamic>?;
    final location = geometry != null
        ? geometry['location'] as Map<String, dynamic>?
        : null;

    if (location == null) return null;

    final lat = (location['lat'] as num?)?.toDouble();
    final lng = (location['lng'] as num?)?.toDouble();

    if (lat == null || lng == null) return null;

    return PlaceDetailsResult(
      formattedAddress: formattedAddress,
      lat: lat,
      lng: lng,
    );
  }
}
