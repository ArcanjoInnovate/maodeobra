// lib/services/ibge_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class Estado {
  final int id;
  final String sigla;
  final String nome;

  Estado({
    required this.id,
    required this.sigla,
    required this.nome,
  });

  factory Estado.fromJson(Map<String, dynamic> json) {
    return Estado(
      id: json['id'],
      sigla: json['sigla'],
      nome: json['nome'],
    );
  }
}

class Cidade {
  final int id;
  final String nome;

  Cidade({
    required this.id,
    required this.nome,
  });

  factory Cidade.fromJson(Map<String, dynamic> json) {
    return Cidade(
      id: json['id'],
      nome: json['nome'],
    );
  }
}

class IBGEService {
  static const String _baseUrl = 'https://servicodados.ibge.gov.br/api/v1/localidades';

  // Cache para evitar requisições desnecessárias
  static List<Estado>? _cachedEstados;
  static Map<String, List<Cidade>> _cachedCidades = {};

  // Buscar todos os estados
  Future<List<Estado>> getEstados() async {
    if (_cachedEstados != null) {
      return _cachedEstados!;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/estados?orderBy=nome'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _cachedEstados = data.map((json) => Estado.fromJson(json)).toList();
        return _cachedEstados!;
      } else {
        throw Exception('Erro ao buscar estados');
      }
    } catch (e) {
      print('Erro ao buscar estados: $e');
      return [];
    }
  }

  // Buscar cidades de um estado específico
  Future<List<Cidade>> getCidadesPorEstado(String siglaEstado) async {
    if (_cachedCidades.containsKey(siglaEstado)) {
      return _cachedCidades[siglaEstado]!;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/estados/$siglaEstado/municipios?orderBy=nome'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final cidades = data.map((json) => Cidade.fromJson(json)).toList();
        _cachedCidades[siglaEstado] = cidades;
        return cidades;
      } else {
        throw Exception('Erro ao buscar cidades');
      }
    } catch (e) {
      print('Erro ao buscar cidades: $e');
      return [];
    }
  }

  // Limpar cache
  void clearCache() {
    _cachedEstados = null;
    _cachedCidades.clear();
  }
}
