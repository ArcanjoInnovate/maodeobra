import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:video_player/video_player.dart';

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

  void _showStateDialog() async{
    await showDialog(
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B35),
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
                                      ? const Color(0xFFFF6B35).withOpacity(0.1)
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
                                            ? const Color(0xFFFF6B35)
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
                                              ? const Color(0xFFFF6B35)
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
                                        color: Color(0xFFFF6B35),
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      FocusScope.of(context).unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estado',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showStateDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.map,
                  color: Color(0xFFFF6B35),
                  size: 20,
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
                          ? Colors.black87
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

  void _showCityDialog() async{
    if (widget.selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecione um estado primeiro'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    await showDialog(
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B35),
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
                                              ? const Color(0xFFFF6B35).withOpacity(0.1)
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
                                                  ? const Color(0xFFFF6B35)
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
                                                      ? const Color(0xFFFF6B35)
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
                                                color: Color(0xFFFF6B35),
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      FocusScope.of(context).unfocus();
    });
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
        Text(
          'Cidade',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: isEnabled ? _showCityDialog : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEnabled ? Colors.grey[300]! : Colors.grey[200]!,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_city,
                  color: isEnabled ? Color(0xFFFF6B35) : Colors.grey[300],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCity ?? 'Selecione a cidade',
                    style: TextStyle(
                      color: selectedCity != null
                          ? Colors.black87
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

// ==================== PROFESSION DROPDOWN ====================
class ProfessionDropdown extends StatefulWidget {
  final Function(String?)? onChanged;
  final String? initialValue;

  const ProfessionDropdown({Key? key, this.onChanged, this.initialValue})
      : super(key: key);

  @override
  State<ProfessionDropdown> createState() => _ProfessionDropdownState();
}

class _ProfessionDropdownState extends State<ProfessionDropdown> {
  String? selectedProfession;
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  final List<String> professions = [
    'Arquiteto',
    'Engenheiro Civil',
    'Engenheiro de Estruturas',
    'Engenheiro de Fundações',
    'Engenheiro Geotécnico',
    'Engenheiro de Segurança do Trabalho',
    'Engenheiro Ambiental',
    'Tecnólogo em Construção Civil',
    'Mestre de Obras',
    'Encarregado de Obras',
    'Fiscal de Obras',
    'Coordenador de Projetos',
    'Gerente de Obras',
    'Planejador de Obras',
    'Orçamentista',
    'Topógrafo',
    'Desenhista Técnico',
    'Projetista',
    'Pedreiro',
    'Servente de Pedreiro',
    'Armador',
    'Ferreiro',
    'Carpinteiro',
    'Carpinteiro de Formas',
    'Concreteiro',
    'Operador de Betoneira',
    'Poceiro',
    'Fundador',
    'Azulejista',
    'Ladrilheiro',
    'Marmorista',
    'Graniteiro',
    'Gesseiro',
    'Estucador',
    'Rebocador',
    'Pintor',
    'Pintor de Obras',
    'Texturizador',
    'Impermeabilizador',
    'Aplicador de Revestimento',
    'Ceramista',
    'Eletricista',
    'Eletricista de Obras',
    'Eletricista Industrial',
    'Encanador',
    'Bombeiro Hidráulico',
    'Instalador Hidráulico',
    'Instalador de Gás',
    'Gasista',
    'Instalador de Ar Condicionado',
    'Instalador de Telefonia',
    'Instalador de Rede de Dados',
    'Instalador de CFTV',
    'Instalador de Sistemas de Segurança',
    'Marceneiro',
    'Serralheiro',
    'Vidraceiro',
    'Instalador de Esquadrias',
    'Montador de Móveis',
    'Forrador',
    'Instalador de Forro',
    'Divisorista (Drywall)',
    'Gessista',
    'Asfaltador',
    'Pavimentador',
    'Operador de Máquinas',
    'Operador de Retroescavadeira',
    'Operador de Escavadeira',
    'Operador de Rolo Compactador',
    'Operador de Motoniveladora',
    'Operador de Pá Carregadeira',
    'Operador de Trator',
    'Motorista de Caminhão',
    'Motorista de Caminhão Basculante',
    'Operador de Guindaste',
    'Operador de Munck',
    'Operador de Empilhadeira',
    'Telhador',
    'Instalador de Telhas',
    'Instalador de Calhas',
    'Instalador de Rufos',
    'Instalador de Estruturas Metálicas',
    'Soldador',
    'Montador',
    'Montador de Andaimes',
    'Instalador de Elevadores',
    'Técnico em Elevadores',
    'Instalador de Piscinas',
    'Paisagista',
    'Jardineiro de Obras',
    'Demolidor',
    'Perfurador',
    'Cortador de Concreto',
    'Operador de Jato de Areia',
    'Técnico de Manutenção Predial',
    'Reparador',
    'Restaurador',
    'Recuperador de Estruturas',
    'Inspetor de Qualidade',
    'Técnico em Controle de Qualidade',
    'Laboratorista',
    'Ensaiador de Materiais',
    'Almoxarife',
    'Auxiliar de Almoxarifado',
    'Comprador',
    'Auxiliar Administrativo de Obras',
    'Apontador de Obras',
    'Auxiliar de Obras',
    'Ajudante Geral',
    'Ceifeiro de Almas',
    'Servente de Obras',
    'Zelador de Obras',
    'Vigia de Obras',
  ]..sort();

  @override
  void initState() {
    super.initState();
    selectedProfession = widget.initialValue;
  }

  List<String> get filteredProfessions {
    if (searchQuery.isEmpty) {
      return professions;
    }
    return professions
        .where(
          (profession) =>
              profession.toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _showSearchDialog() async{
    
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: BoxConstraints(maxHeight: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFF3B82F6),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: searchController,
                              autofocus: false,
                              decoration: InputDecoration(
                                hintText: 'Pesquisar profissão...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey[600],
                                ),
                                suffixIcon: searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear),
                                        onPressed: () {
                                          setDialogState(() {
                                            searchController.clear();
                                            searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
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
                    Expanded(
                      child: filteredProfessions.isEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(25),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Nenhuma profissão encontrada',
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
                              shrinkWrap: true,
                              itemCount: filteredProfessions.length,
                              itemBuilder: (context, index) {
                                final profession = filteredProfessions[index];
                                final isSelected =
                                    profession == selectedProfession;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedProfession = profession;
                                    });
                                    if (widget.onChanged != null) {
                                      widget.onChanged!(profession);
                                    }
                                    Navigator.pop(dialogContext);
                                    searchController.clear();
                                    searchQuery = '';
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Color(0xFF3B82F6).withOpacity(0.1)
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
                                          Icons.engineering,
                                          color: isSelected
                                              ? Color(0xFF3B82F6)
                                              : Colors.grey[600],
                                          size: 22,
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            profession,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: isSelected
                                                  ? Color(0xFF3B82F6)
                                                  : Colors.black87,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      FocusScope.of(context).unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profissão',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: _showSearchDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFD1D5DB), width: 1),
              color: Color(0xFFF9FAFB),
            ),
            child: Row(
              children: [
                Icon(Icons.engineering, color: Colors.grey[400], size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedProfession ?? 'Selecione sua profissão',
                    style: TextStyle(
                      color: selectedProfession != null
                          ? Color(0xFF1F2937)
                          : Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
        if (selectedProfession != null)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 16),
                SizedBox(width: 6),
                Text(
                  'Profissão selecionada',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ==================== CURRENCY INPUT FORMATTER ====================
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String numbersOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (numbersOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    double value = double.parse(numbersOnly) / 100;
    String formatted = 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

    List<String> parts = formatted.split(',');
    String integerPart = parts[0].replaceAll('R\$ ', '');

    String formattedInteger = '';
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count == 3) {
        formattedInteger = '.$formattedInteger';
        count = 0;
      }
      formattedInteger = integerPart[i] + formattedInteger;
      count++;
    }

    formatted = 'R\$ $formattedInteger,${parts[1]}';

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ==================== FULLSCREEN MEDIA VIEWER ====================
class FullscreenMediaViewer extends StatefulWidget {
  final List<File>? images;
  final List<File>? videos;
  final int initialIndex;
  final bool isVideo;

  FullscreenMediaViewer({
    this.images,
    this.videos,
    required this.initialIndex,
    required this.isVideo,
  });

  @override
  _FullscreenMediaViewerState createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer> {
  late PageController _pageController;
  int _currentIndex = 0;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    if (widget.isVideo) {
      _initializeVideoPlayer(widget.initialIndex);
    }
  }

  void _initializeVideoPlayer(int index) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(widget.videos![index])
      ..initialize().then((_) {
        setState(() {});
        _videoController!.play();
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.isVideo ? widget.videos! : widget.images!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: items.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              if (widget.isVideo) {
                _initializeVideoPlayer(index);
              }
            },
            itemBuilder: (context, index) {
              if (widget.isVideo) {
                return Center(
                  child: _videoController != null &&
                          _videoController!.value.isInitialized &&
                          index == _currentIndex
                      ? GestureDetector(
                          onTap: () {
                            setState(() {
                              _videoController!.value.isPlaying
                                  ? _videoController!.pause()
                                  : _videoController!.play();
                            });
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),
                              if (!_videoController!.value.isPlaying)
                                Icon(
                                  Icons.play_circle_fill,
                                  size: 80,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              Positioned(
                                bottom: 20,
                                left: 20,
                                right: 20,
                                child: Column(
                                  children: [
                                    VideoProgressIndicator(
                                      _videoController!,
                                      allowScrubbing: true,
                                      colors: VideoProgressColors(
                                        playedColor: Color(0xFFFF6B35),
                                        bufferedColor: Colors.white24,
                                        backgroundColor: Colors.white12,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(_videoController!.value.position),
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        Text(
                                          _formatDuration(_videoController!.value.duration),
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                );
              } else {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.file(items[index], fit: BoxFit.contain),
                  ),
                );
              }
            },
          ),
          SafeArea(
            child: Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
          if (items.length > 1)
            SafeArea(
              child: Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${items.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}