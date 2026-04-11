// lib/widgets/feed_filters.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dartobra_new/controllers/feed_controller.dart';
import 'package:dartobra_new/services/search/ibge_service.dart';

class FeedFilters extends StatefulWidget {
  @override
  _FeedFiltersState createState() => _FeedFiltersState();
}

class _FeedFiltersState extends State<FeedFilters> {
  String? _selectedState;
  String? _selectedCity;
  String? _selectedProfession;

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedController>(
      builder: (context, controller, child) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtros',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_hasActiveFilters(controller))
                    TextButton(
                      onPressed: () => _clearFilters(controller),
                      child: Text('Limpar Filtros'),
                    ),
                ],
              ),
              
              SizedBox(height: 16),

              // Filtro de Estado
              _buildStateFilter(controller),
              
              SizedBox(height: 12),

              // Filtro de Cidade (só aparece se tem estado)
              if (_selectedState != null)
                _buildCityFilter(controller),
              
              SizedBox(height: 12),

              // Filtro de Profissão (só no modo contractor)
              if (controller.feedMode == FeedMode.contractor)
                _buildProfessionFilter(controller),
              
              SizedBox(height: 16),

              // Botão Aplicar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _applyFilters(controller),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Aplicar Filtros'),
                ),
              ),

              // Stats
              SizedBox(height: 8),
              Center(
                child: Text(
                  controller.feedStats,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStateFilter(FeedController controller) {
    return DropdownButtonFormField<String>(
      value: _selectedState,
      decoration: InputDecoration(
        labelText: 'Estado',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_on),
      ),
      hint: Text('Selecione o estado'),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Todos os estados'),
        ),
        ...controller.availableStates.map((estado) {
          return DropdownMenuItem<String>(
            value: estado.sigla,
            child: Text('${estado.sigla} - ${estado.nome}'),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _selectedState = value;
          _selectedCity = null; // Reseta cidade quando muda estado
        });
      },
    );
  }

  Widget _buildCityFilter(FeedController controller) {
    if (controller.loadingCities) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedCity,
      decoration: InputDecoration(
        labelText: 'Cidade',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_city),
      ),
      hint: Text('Selecione a cidade'),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Todas as cidades'),
        ),
        ...controller.availableCities.map((cidade) {
          return DropdownMenuItem<String>(
            value: cidade.nome,
            child: Text(cidade.nome),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCity = value;
        });
      },
    );
  }

  Widget _buildProfessionFilter(FeedController controller) {
    // Lista de profissões comuns
    final professions = [
      'Pedreiro',
      'Eletricista',
      'Encanador',
      'Pintor',
      'Carpinteiro',
      'Serralheiro',
      'Gesseiro',
      'Azulejista',
      'Auxiliar de Obras',
      'Servente',
      'Mestre de Obras',
      'Engenheiro',
      'Arquiteto',
      'Técnico em Edificações',
    ];

    return DropdownButtonFormField<String>(
      value: _selectedProfession,
      decoration: InputDecoration(
        labelText: 'Profissão',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.work),
      ),
      hint: Text('Selecione a profissão'),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Todas as profissões'),
        ),
        ...professions.map((prof) {
          return DropdownMenuItem<String>(
            value: prof,
            child: Text(prof),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _selectedProfession = value;
        });
      },
    );
  }

  bool _hasActiveFilters(FeedController controller) {
    return controller.filterState != null ||
           controller.filterCity != null ||
           controller.preferredProfession != null;
  }

  Future<void> _applyFilters(FeedController controller) async {
    await controller.applyFilters(
      state: _selectedState,
      city: _selectedCity,
      profession: _selectedProfession,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Filtros aplicados!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearFilters(FeedController controller) async {
    setState(() {
      _selectedState = null;
      _selectedCity = null;
      _selectedProfession = null;
    });

    await controller.clearFilters();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Filtros limpos!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}