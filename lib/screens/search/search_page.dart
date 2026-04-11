// lib/pages/search_page.dart

import 'package:dartobra_new/controllers/search_controller.dart' as search;
import 'package:dartobra_new/widgets/feed/professional_card.dart';
import 'package:dartobra_new/widgets/feed/vacancy_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    
    // ✅ Carrega dados apenas na primeira vez
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<search.SearchController>();
      if (!controller.isLoading) {
        controller.initialize();
      }
    });

    // ✅ Setup scroll listener para load more
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ✅ SCROLL INFINITO
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      // Carrega mais quando chegar a 80% do scroll
      context.read<search.SearchController>().loadMoreItems();
    }
  }

  // ✅ PULL TO REFRESH - FORÇA REFRESH COMPLETO
  Future<void> _refreshData() async {
    final controller = context.read<search.SearchController>();
    await controller.forceRefresh();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<search.SearchController>().updateSearchQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<search.SearchController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Carregando dados...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (controller.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Ops! Algo deu errado',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => controller.initialize(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: Column(
              children: [
                // Barra de busca e filtros
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          children: [
                            // Campo de busca
                            TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText: 'Buscar...',
                                hintStyle: TextStyle(color: Colors.grey.shade500),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey.shade600,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          controller.updateSearchQuery('');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Toggle de tipo - CORRIGIDO
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SegmentedButton<search.SearchType>(
                                segments: const [
                                  ButtonSegment(
                                    value: search.SearchType.professionals,
                                    label: Text('Profissionais'),
                                    icon: Icon(Icons.person_outline, size: 20),
                                  ),
                                  ButtonSegment(
                                    value: search.SearchType.vacancies,
                                    label: Text('Vagas'),
                                    icon: Icon(Icons.work_outline, size: 20),
                                  ),
                                ],
                                selected: {controller.searchType},
                                onSelectionChanged:
                                    (Set<search.SearchType> newSelection) {
                                      // ✅ CORRIGIDO: changeSearchType ao invés de toggleSearchType
                                      controller.changeSearchType(
                                        newSelection.first,
                                      );
                                    },
                                style: ButtonStyle(
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                        if (states.contains(
                                          WidgetState.selected,
                                        )) {
                                          return Colors.blue.shade700;
                                        }
                                        return Colors.transparent;
                                      }),
                                  foregroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                        if (states.contains(
                                          WidgetState.selected,
                                        )) {
                                          return Colors.white;
                                        }
                                        return Colors.grey.shade700;
                                      }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Chips de filtros
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            // Filtro de Estado
                            _buildFilterChip(
                              label: controller.selectedState ?? 'Estado',
                              icon: Icons.map_outlined,
                              selected: controller.selectedState != null,
                              onTap: () => _showStatePicker(context, controller),
                            ),
                            const SizedBox(width: 8),

                            // Filtro de Cidade
                            _buildFilterChip(
                              label: controller.selectedCity ?? 'Cidade',
                              icon: Icons.location_city_outlined,
                              selected: controller.selectedCity != null,
                              onTap: () {
                                if (controller.selectedState == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Selecione um estado primeiro',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  _showCityPicker(context, controller);
                                }
                              },
                              enabled: controller.selectedState != null,
                            ),
                            const SizedBox(width: 8),

                            // Filtro de Profissão
                            _buildFilterChip(
                              label: controller.selectedProfession ?? 'Profissão',
                              icon: Icons.work_outline,
                              selected: controller.selectedProfession != null,
                              onTap: () =>
                                  _showProfessionPicker(context, controller),
                            ),
                            const SizedBox(width: 8),

                            // Limpar filtros
                            if (controller.selectedCity != null ||
                                controller.selectedState != null ||
                                controller.selectedProfession != null ||
                                controller.selectedCompany != null)
                              _buildClearButton(controller),
                          ],
                        ),
                      ),

                      Divider(height: 1, color: Colors.grey.shade200),
                    ],
                  ),
                ),

                // Lista de resultados
                Expanded(child: _buildResultsList(controller)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade700 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.blue.shade700 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? Colors.white
                  : (enabled ? Colors.grey.shade700 : Colors.grey.shade400),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected
                    ? Colors.white
                    : (enabled ? Colors.grey.shade700 : Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearButton(search.SearchController controller) {
    return InkWell(
      onTap: () {
        controller.clearFilters();
        _searchController.clear();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade200, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close, size: 18, color: Colors.red.shade700),
            const SizedBox(width: 6),
            Text(
              'Limpar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(search.SearchController controller) {
    final isProfessionals =
        controller.searchType == search.SearchType.professionals;

    if (isProfessionals) {
      return _buildProfessionalsList(controller);
    } else {
      return _buildVacanciesList(controller);
    }
  }

  Widget _buildProfessionalsList(search.SearchController controller) {
    final professionals = controller.filteredProfessionals;

    if (professionals.isEmpty && !controller.isLoadingMore) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhum profissional encontrado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tente ajustar os filtros',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      );
    }
  final showLoader = controller.isLoadingMore && professionals.isNotEmpty;
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 16),


      itemCount: professionals.length + (showLoader ? 1 : 0),

      itemBuilder: (context, index) {
        // ✅ Loading indicator no final
        if (showLoader && index == professionals.length) {

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: Colors.blue.shade700,
              ),
            ),
          );
        }

        return ProfessionalCard(
          professional: professionals[index],
        );
      },
    );
  }

  Widget _buildVacanciesList(search.SearchController controller) {
    final vacancies = controller.filteredVacancies;

    if (vacancies.isEmpty && !controller.isLoadingMore) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.work_off_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma vaga encontrada',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tente ajustar os filtros',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      itemCount: vacancies.length + (controller.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // ✅ Loading indicator no final
        if (index == vacancies.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: Colors.blue.shade700,
              ),
            ),
          );
        }

        return VacancyCard(vacancy: vacancies[index]);
      },
    );
  }

  void _showStatePicker(
    BuildContext context,
    search.SearchController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Selecione o Estado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.clear),
                  title: const Text('Todos os estados'),
                  onTap: () {
                    controller.selectState(null);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ...controller.estados.map(
                  (estado) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: Text(
                        estado.sigla,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(estado.nome),
                    trailing: controller.selectedState == estado.sigla
                        ? Icon(Icons.check, color: Colors.blue.shade700)
                        : null,
                    onTap: () {
                      controller.selectState(estado.sigla);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCityPicker(
    BuildContext context,
    search.SearchController controller,
  ) {
    if (controller.loadingCidades) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Selecione a Cidade',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.clear),
                  title: const Text('Todas as cidades'),
                  onTap: () {
                    controller.selectCity(null);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ...controller.cidades.map(
                  (cidade) => ListTile(
                    leading: const Icon(Icons.location_city),
                    title: Text(cidade.nome),
                    trailing: controller.selectedCity == cidade.nome
                        ? Icon(Icons.check, color: Colors.blue.shade700)
                        : null,
                    onTap: () {
                      controller.selectCity(cidade.nome);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProfessionPicker(
    BuildContext context,
    search.SearchController controller,
  ) {
    final professions = controller.getAvailableProfessions();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Selecione a Profissão',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: professions.isEmpty
                ? const Center(child: Text('Nenhuma profissão disponível'))
                : ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.clear),
                        title: const Text('Todas as profissões'),
                        onTap: () {
                          controller.selectProfession(null);
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(height: 1),
                      ...professions.map(
                        (profession) => ListTile(
                          leading: const Icon(Icons.work),
                          title: Text(profession),
                          trailing: controller.selectedProfession == profession
                              ? Icon(Icons.check, color: Colors.blue.shade700)
                              : null,
                          onTap: () {
                            controller.selectProfession(profession);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}