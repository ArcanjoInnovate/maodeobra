import 'package:flutter/material.dart';

// ==================== PROFESSION DROPDOWN ====================
class ProfessionDropdown extends StatefulWidget {
  final Function(String?)? onChanged;
  final String? initialValue;
  
  const ProfessionDropdown({
    Key? key,
    this.onChanged,
    this.initialValue,
  }) : super(key: key);

  @override
  State<ProfessionDropdown> createState() => _ProfessionDropdownState();
}

class _ProfessionDropdownState extends State<ProfessionDropdown> {
  String? selectedProfession;
  String searchQuery = '';
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  final List<String> professions = [
    // Profissões de Planejamento e Gestão
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
    
    // Profissões de Estrutura e Fundação
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
    
    // Profissões de Acabamento
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
    
    // Profissões de Instalações
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
    
    // Profissões de Esquadrias e Acabamento
    'Marceneiro',
    'Serralheiro',
    'Vidraceiro',
    'Instalador de Esquadrias',
    'Montador de Móveis',
    'Forrador',
    'Instalador de Forro',
    'Divisorista (Drywall)',
    'Gessista',
    
    // Profissões de Pavimentação e Terraplanagem
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
    
    // Profissões de Cobertura
    'Telhador',
    'Instalador de Telhas',
    'Instalador de Calhas',
    'Instalador de Rufos',
    'Instalador de Estruturas Metálicas',
    
    // Profissões Especializadas
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
    
    // Profissões de Manutenção e Reparos
    'Técnico de Manutenção Predial',
    'Reparador',
    'Restaurador',
    'Recuperador de Estruturas',
    
    // Profissões de Controle de Qualidade
    'Inspetor de Qualidade',
    'Técnico em Controle de Qualidade',
    'Laboratorista',
    'Ensaiador de Materiais',
    
    // Profissões Administrativas
    'Almoxarife',
    'Auxiliar de Almoxarifado',
    'Comprador',
    'Auxiliar Administrativo de Obras',
    'Apontador de Obras',
    
    // Profissões de Limpeza e Auxiliares
    'Auxiliar de Obras',
    'Ajudante Geral',
    'Ceifeiro de Almas',
    'Servente de Obras',
    'Zelador de Obras',
    'Vigia de Obras',
  ]..sort(); // Ordena alfabeticamente

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
        .where((profession) =>
            profession.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  void _showSearchDialog() {
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
                    // Header com campo de busca
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
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
                                hintText: 'Pesquisar profissão...',
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
                    // Lista de profissões
                    Expanded(
                      child: filteredProfessions.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(25),
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
                                final isSelected = profession == selectedProfession;
                                
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedProfession = profession;
                                    });
                                    if (widget.onChanged != null) {
                                      widget.onChanged!(profession);
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
                                        Icon(
                                          Icons.engineering,
                                          color: isSelected
                                              ? const Color(0xFF3B82F6)
                                              : Colors.grey[600],
                                          size: 22,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            profession,
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
    ).then((_) {
      // Limpa a busca quando o dialog fecha
      searchController.clear();
      searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profissão',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showSearchDialog,
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
                  Icons.engineering,
                  color: Colors.grey[400],
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedProfession ?? 'Selecione sua profissão',
                    style: TextStyle(
                      color: selectedProfession != null
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
        if (selectedProfession != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: const Color(0xFF3B82F6),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Profissão selecionada',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ==================== PROFESSIONAL SUMMARY FIELD ====================
class ProfessionalSummaryField extends StatefulWidget {
  final Function(String)? onChanged;
  final int maxCharacters;
  final String? initialValue;
  
  const ProfessionalSummaryField({
    Key? key,
    this.onChanged,
    this.maxCharacters = 500,
    this.initialValue,
  }) : super(key: key);

  @override
  State<ProfessionalSummaryField> createState() => _ProfessionalSummaryFieldState();
}

class _ProfessionalSummaryFieldState extends State<ProfessionalSummaryField> {
  final TextEditingController _controller = TextEditingController();
  int _characterCount = 0;

  @override
  void initState() {
    super.initState();
    // Inicializar com valor inicial se houver
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _controller.text = widget.initialValue!;
      _characterCount = widget.initialValue!.length;
    }
    
    _controller.addListener(() {
      setState(() {
        _characterCount = _controller.text.length;
      });
      if (widget.onChanged != null) {
        widget.onChanged!(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumo Profissional',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFD1D5DB),
              width: 1,
            ),
            color: const Color(0xFFF9FAFB),
          ),
          child: TextField(
            controller: _controller,
            maxLines: 5,
            maxLength: widget.maxCharacters,
            decoration: InputDecoration(
              hintText: 'Descreva sua experiência, especialidades e diferenciais...',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
              counterText: '', // Remove o contador padrão do Flutter
            ),
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Text(
            '$_characterCount/${widget.maxCharacters} caracteres',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== SKILLS FIELD ====================
class SkillsField extends StatefulWidget {
  final Function(List<String>)? onSkillsChanged;
  final List<String>? initialSkills;
  
  const SkillsField({
    Key? key,
    this.onSkillsChanged,
    this.initialSkills,
  }) : super(key: key);

  @override
  State<SkillsField> createState() => _SkillsFieldState();
}

class _SkillsFieldState extends State<SkillsField> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _skills;
  
  final List<String> _suggestions = [
    'Trabalho em equipe',
    'Pontualidade',
    'Atenção aos detalhes',
  ];

  @override
  void initState() {
    super.initState();
    // Inicializar com skills existentes
    _skills = widget.initialSkills != null 
        ? List<String>.from(widget.initialSkills!)
        : [];
  }

  void _addSkill() {
    final skill = _controller.text.trim();
    if (skill.isNotEmpty && !_skills.contains(skill)) {
      setState(() {
        _skills.add(skill);
        _controller.clear();
      });
      if (widget.onSkillsChanged != null) {
        widget.onSkillsChanged!(_skills);
      }
    }
  }

  void _removeSkill(int index) {
    setState(() {
      _skills.removeAt(index);
    });
    if (widget.onSkillsChanged != null) {
      widget.onSkillsChanged!(_skills);
    }
  }

  void _addSuggestion(String suggestion) {
    if (!_skills.contains(suggestion)) {
      setState(() {
        _skills.add(suggestion);
      });
      if (widget.onSkillsChanged != null) {
        widget.onSkillsChanged!(_skills);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Habilidades',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        
        // Campo de input com botão
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD1D5DB),
                    width: 1,
                  ),
                  color: const Color(0xFFF9FAFB),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Icon(
                        Icons.star_border,
                        color: Colors.grey[400],
                        size: 22,
                      ),
                    ),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Digite uma habilidade',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.only(
                          left: 44,
                          right: 16,
                          top: 12,
                          bottom: 12,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1F2937),
                      ),
                      onSubmitted: (_) => _addSkill(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _addSkill,
                icon: const Icon(Icons.add, color: Colors.white),
                padding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Lista de habilidades ou mensagem vazia
        if (_skills.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFDBEAFE),
                width: 1,
              ),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _skills.asMap().entries.map((entry) {
                final index = entry.key;
                final skill = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFBFDBFE),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        skill,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _removeSkill(index),
                        borderRadius: BorderRadius.circular(12),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD1D5DB),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star_border,
                  size: 20,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 10),
                Text(
                  'Adicione suas principais habilidades',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 12),
        
        // Sugestões de habilidades
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((suggestion) {
            final isAdded = _skills.contains(suggestion);
            return InkWell(
              onTap: () => _addSuggestion(suggestion),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isAdded 
                      ? const Color(0xFFE5E7EB) 
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 14,
                      color: isAdded 
                          ? Colors.grey[400] 
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 12,
                        color: isAdded 
                            ? Colors.grey[400] 
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16),
      ],
    );
  }
}
