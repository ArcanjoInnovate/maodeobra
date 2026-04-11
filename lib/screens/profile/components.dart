import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ==================== AGE TEXT FIELD ====================
class AgeTextField extends StatefulWidget {
  final TextEditingController controller;
  final int minAge;
  final int maxAge;

  const AgeTextField({
    Key? key,
    required this.controller,
    this.minAge = 16,
    this.maxAge = 100,
  }) : super(key: key);

  @override
  State<AgeTextField> createState() => _AgeTextFieldState();
}

class _AgeTextFieldState extends State<AgeTextField> {
  void _incrementAge() {
    int currentAge = int.tryParse(widget.controller.text) ?? widget.minAge;
    if (currentAge < widget.maxAge) {
      widget.controller.text = (currentAge + 1).toString();
    }
  }

  void _decrementAge() {
    int currentAge = int.tryParse(widget.controller.text) ?? widget.minAge;
    if (currentAge > widget.minAge) {
      widget.controller.text = (currentAge - 1).toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD1D5DB),
          width: 1,
        ),
        color: const Color(0xFFF9FAFB),
      ),
      child: Row(
        children: [
          // Botão Decrementar
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _decrementAge,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: const Color(0xFFD1D5DB),
                      width: 1,
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.remove,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
            ),
          ),

          // Campo de Texto
          Expanded(
            child: TextField(
              controller: widget.controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
                _AgeInputFormatter(widget.minAge, widget.maxAge),
              ],
              decoration: InputDecoration(
                hintText: 'Idade',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),

          // Botão Incrementar
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _incrementAge,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: const Color(0xFFD1D5DB),
                      width: 1,
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Formatter para validar idade durante a digitação
class _AgeInputFormatter extends TextInputFormatter {
  final int minAge;
  final int maxAge;

  _AgeInputFormatter(this.minAge, this.maxAge);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final int? age = int.tryParse(newValue.text);
    if (age == null) {
      return oldValue;
    }

    if (age > maxAge) {
      return oldValue;
    }

    return newValue;
  }
}

// ==================== STATE DROPDOWN ====================
class StateDropdown extends StatefulWidget {
  final Function(String?)? onChanged;
  final String? initialValue;

  const StateDropdown({
    Key? key,
    this.onChanged,
    this.initialValue,
  }) : super(key: key);

  @override
  State<StateDropdown> createState() => _StateDropdownState();
}

class _StateDropdownState extends State<StateDropdown> {
  String? selectedState;
  List<Map<String, dynamic>> states = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    selectedState = widget.initialValue;
    _loadStates();
  }

  Future<void> _loadStates() async {
    try {
      final response = await http.get(
        Uri.parse('https://servicodados.ibge.gov.br/api/v1/localidades/estados'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          states = data.map((state) => {
            'id': state['id'],
            'sigla': state['sigla'],
            'nome': state['nome'],
          }).toList();
          states.sort((a, b) => a['nome'].compareTo(b['nome']));
          isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar estados: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showStateDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Selecione o Estado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Lista de estados
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: states.length,
                          itemBuilder: (context, index) {
                            final state = states[index];
                            final isSelected = state['sigla'] == selectedState;
                            
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  selectedState = state['sigla'];
                                });
                                if (widget.onChanged != null) {
                                  widget.onChanged!(state['sigla']);
                                }
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF3B82F6).withOpacity(0.1)
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[200]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF3B82F6)
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          state['sigla'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        state['nome'],
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isSelected
                                              ? const Color(0xFF3B82F6)
                                              : Colors.black87,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF3B82F6),
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showStateDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD1D5DB),
                width: 1,
              ),
              color: const Color(0xFFF9FAFB),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.map,
                  color: Colors.grey[400],
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedState != null
                        ? states.firstWhere(
                            (s) => s['sigla'] == selectedState,
                            orElse: () => {'nome': selectedState},
                          )['nome']
                        : 'Selecione o estado',
                    style: TextStyle(
                      color: selectedState != null
                          ? const Color(0xFF1F2937)
                          : Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== CITY DROPDOWN ====================
class CityDropdown extends StatefulWidget {
  final String? selectedState;
  final Function(String?)? onChanged;
  final String? initialValue;

  const CityDropdown({
    Key? key,
    this.selectedState,
    this.onChanged,
    this.initialValue,
  }) : super(key: key);

  @override
  State<CityDropdown> createState() => _CityDropdownState();
}

class _CityDropdownState extends State<CityDropdown> {
  String? selectedCity;
  List<Map<String, dynamic>> cities = [];
  bool isLoading = false;
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedCity = widget.initialValue;
    if (widget.selectedState != null) {
      _loadCities(widget.selectedState!);
    }
  }

  @override
  void didUpdateWidget(CityDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedState != oldWidget.selectedState) {
      selectedCity = null;
      if (widget.selectedState != null) {
        _loadCities(widget.selectedState!);
      } else {
        setState(() {
          cities = [];
        });
      }
    }
  }

  Future<void> _loadCities(String stateCode) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Primeiro, busca o ID do estado pela sigla
      final statesResponse = await http.get(
        Uri.parse('https://servicodados.ibge.gov.br/api/v1/localidades/estados'),
      );

      if (statesResponse.statusCode == 200) {
        final List<dynamic> statesData = json.decode(statesResponse.body);
        final state = statesData.firstWhere(
          (s) => s['sigla'] == stateCode,
          orElse: () => null,
        );

        if (state != null) {
          final stateId = state['id'];
          
          // Agora busca as cidades do estado
          final citiesResponse = await http.get(
            Uri.parse(
              'https://servicodados.ibge.gov.br/api/v1/localidades/estados/$stateId/municipios',
            ),
          );

          if (citiesResponse.statusCode == 200) {
            final List<dynamic> citiesData = json.decode(citiesResponse.body);
            setState(() {
              cities = citiesData.map((city) => {
                'id': city['id'],
                'nome': city['nome'],
              }).toList();
              cities.sort((a, b) => a['nome'].compareTo(b['nome']));
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Erro ao carregar cidades: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredCities {
    if (searchQuery.isEmpty) {
      return cities;
    }
    return cities
        .where((city) =>
            city['nome'].toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  void _showCityDialog() {
    if (widget.selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um estado primeiro'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header com busca
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_city, color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Selecione a Cidade',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () {
                                  searchController.clear();
                                  searchQuery = '';
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Campo de busca
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: searchController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Pesquisar cidade...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                                suffixIcon: searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          setDialogState(() {
                                            searchController.clear();
                                            searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onChanged: (value) {
                                setDialogState(() {
                                  searchQuery = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Lista de cidades
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filteredCities.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.search_off,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Nenhuma cidade encontrada',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredCities.length,
                                  itemBuilder: (context, index) {
                                    final city = filteredCities[index];
                                    final isSelected = city['nome'] == selectedCity;
                                    
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedCity = city['nome'];
                                        });
                                        if (widget.onChanged != null) {
                                          widget.onChanged!(city['nome']);
                                        }
                                        searchController.clear();
                                        searchQuery = '';
                                        Navigator.pop(context);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF3B82F6).withOpacity(0.1)
                                              : Colors.transparent,
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey[200]!,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.location_city,
                                              color: isSelected
                                                  ? const Color(0xFF3B82F6)
                                                  : Colors.grey[600],
                                              size: 22,
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                city['nome'],
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: isSelected
                                                      ? const Color(0xFF3B82F6)
                                                      : Colors.black87,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              const Icon(
                                                Icons.check_circle,
                                                color: Color(0xFF3B82F6),
                                                size: 22,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.selectedState != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cidade',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: isEnabled ? _showCityDialog : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEnabled ? const Color(0xFFD1D5DB) : Colors.grey[300]!,
                width: 1,
              ),
              color: isEnabled ? const Color(0xFFF9FAFB) : Colors.grey[100],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_city,
                  color: isEnabled ? Colors.grey[400] : Colors.grey[300],
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCity ?? 'Selecione a cidade',
                    style: TextStyle(
                      color: selectedCity != null
                          ? const Color(0xFF1F2937)
                          : isEnabled
                              ? Colors.grey[400]
                              : Colors.grey[300],
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: isEnabled ? Colors.grey[600] : Colors.grey[300],
                ),
              ],
            ),
          ),
        ),
        if (!isEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  'Selecione um estado primeiro',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}