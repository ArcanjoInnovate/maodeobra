// ignore_for_file: unused_field

import 'package:dartobra_new/services/storage/moderation_image_service.dart';
import 'package:dartobra_new/services/storage/storage_service.dart';
import 'package:dartobra_new/services/vacancy/vacancy_service.dart';
import 'package:dartobra_new/widgets/permissions/permissions_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'components.dart';
import 'dart:io';


class CreateVacancys extends StatefulWidget {
  final bool isEditing;
  final String emailContact;
  final String phoneContact;
  final String localId;

  CreateVacancys({
    this.isEditing = false,
    required this.emailContact,
    required this.phoneContact,
    required this.localId,
  });

  @override
  _CreateVacancysState createState() => _CreateVacancysState();
}

class _CreateVacancysState extends State<CreateVacancys> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final VacancyService _vacancyService = VacancyService();
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorageService _storageService = FirebaseStorageService();

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();

  // FocusNodes
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  final FocusNode _salaryFocus = FocusNode();

  // Profissão e Tipo de Salário
  String? selectedProfession;
  String? selectedSalaryType;

  // Estado e Cidade
  String? selectedState;
  String? selectedCity;

  // Mídia
  List<File> _selectedImages = [];
  List<File> _selectedVideos = [];

  // Loading states
  bool _isUploading = false;
  bool _isCheckingImage = false;
  String _uploadStatus = '';
  double _uploadProgress = 0.0;

  // Lista de tipos de salário
  final List<String> salaryTypes = [
    'Diário',
    'Semanal',
    'Quinzenal',
    'Mensal',
    'Por empreitada',
    'A combinar',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _salaryController.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    _salaryFocus.dispose();
    super.dispose();
  }

  Future<({List<String> imageUrls, List<String> videoUrls})>
      _uploadAllMedia() async {
    final List<String> imageUrls = [];
    final List<String> videoUrls = [];

    final int totalFiles = _selectedImages.length + _selectedVideos.length;
    int currentFile = 0;

    for (final File image in _selectedImages) {
      currentFile++;
      setState(() {
        _uploadStatus = 'Enviando imagem $currentFile de $totalFiles...';
        _uploadProgress = 0.0;
      });

      final String? url = await _storageService.uploadImage(
        file: image,
        folder: 'vacancies',
        userId: widget.localId,
        quality: 70,
        onProgress: (progress) => setState(() => _uploadProgress = progress),
      );

      if (url != null) {
        imageUrls.add(url);
      } else {
        _showSnackBar('Erro ao enviar imagem $currentFile', Colors.red);
      }
    }

    for (final File video in _selectedVideos) {
      currentFile++;
      setState(() {
        _uploadStatus = 'Enviando vídeo $currentFile de $totalFiles...';
        _uploadProgress = 0.0;
      });

      final String? url = await _storageService.uploadVideo(
        file: video,
        folder: 'vacancies',
        userId: widget.localId,
        onProgress: (progress) => setState(() => _uploadProgress = progress),
      );

      if (url != null) {
        videoUrls.add(url);
      } else {
        _showSnackBar('Erro ao enviar vídeo $currentFile', Colors.red);
      }
    }

    return (imageUrls: imageUrls, videoUrls: videoUrls);
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 3) {
      _showSnackBar('Você já adicionou o máximo de 3 fotos', Colors.orange);
      return;
    }

    var result = await PermissionUtil.checkAndRequest(isCamera: false);

    if (result == PermissionResult.denied) {
      final wantsToRetry = await PermissionUtil.showPermissionDialog(
        context: context,
        result: result,
        permissionLabel: 'galeria',
        usageReason: 'para adicionar fotos à vaga',
      );
      if (!wantsToRetry) return;
      result = await PermissionUtil.checkAndRequest(isCamera: false);
    }

    if (result != PermissionResult.granted) {
      await PermissionUtil.showPermissionDialog(
        context: context,
        result: result,
        permissionLabel: 'galeria',
        usageReason: 'para adicionar fotos à vaga',
      );
      return;
    }

    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final int remainingSlots = 3 - _selectedImages.length;
        final List<XFile> candidates = images.take(remainingSlots).toList();

        for (final xfile in candidates) {
          final file = File(xfile.path);

          // ── Moderação via Vision API ────────────────────────────────────
          setState(() => _isCheckingImage = true);
          final approved = await checkAndShowModerationDialog(
            context,
            file,
            onCheckEnd: () => setState(() => _isCheckingImage = false),
          );
          setState(() => _isCheckingImage = false);

          if (!mounted) return;
          if (approved) {
            setState(() => _selectedImages.add(file));
          }
          // Se reprovada, simplesmente ignora e continua para a próxima
        }

        if (images.length > remainingSlots) {
          _showSnackBar(
            'Apenas $remainingSlots foto(s) podiam ser adicionadas. Limite: 3 fotos',
            Colors.orange,
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagens: $e');
      setState(() => _isCheckingImage = false);
      _showSnackBar('Erro ao selecionar imagens', Colors.red);
    }
  }

  Future<void> _pickVideo() async {
    if (_selectedVideos.length >= 1) {
      _showSnackBar('Você já adicionou o máximo de 1 vídeo', Colors.orange);
      return;
    }

    var result = await PermissionUtil.checkAndRequest(isCamera: false);

    if (result == PermissionResult.denied) {
      final wantsToRetry = await PermissionUtil.showPermissionDialog(
        context: context,
        result: result,
        permissionLabel: 'galeria',
        usageReason: 'para adicionar vídeos à vaga',
      );
      if (!wantsToRetry) return;
      result = await PermissionUtil.checkAndRequest(isCamera: false);
    }

    if (result != PermissionResult.granted) {
      await PermissionUtil.showPermissionDialog(
        context: context,
        result: result,
        permissionLabel: 'galeria',
        usageReason: 'para adicionar vídeos à vaga',
      );
      return;
    }

    try {
      final XFile? video =
          await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() => _selectedVideos.add(File(video.path)));
      }
    } catch (e) {
      debugPrint('Erro ao selecionar vídeo: $e');
      _showSnackBar('Erro ao selecionar vídeo', Colors.red);
    }
  }

  void _removeImage(int index) =>
      setState(() => _selectedImages.removeAt(index));
  void _removeVideo(int index) =>
      setState(() => _selectedVideos.removeAt(index));

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static const int _descMinLength = 80;

  bool _validateFields() {
    // 1. Profissão, estado e cidade obrigatórios
    if (selectedProfession == null ||
        selectedState == null ||
        selectedCity == null) {
      _showSnackBar(
        'Por favor, preencha todos os campos obrigatórios',
        Colors.orange,
      );
      return false;
    }

    // 2. Tipo de contrato/salário obrigatório
    if (selectedSalaryType == null) {
      _showSnackBar(
        'Selecione o tipo de contrato antes de criar a vaga',
        Colors.orange,
      );
      return false;
    }

    // 3. Descrição obrigatória e mínimo de 80 caracteres
    final descLength = _descriptionController.text.trim().length;
    if (descLength == 0) {
      _showSnackBar('A descrição é obrigatória', Colors.orange);
      return false;
    }
    if (descLength < _descMinLength) {
      _showSnackBar(
        'A descrição deve ter pelo menos $_descMinLength caracteres (${descLength}/$_descMinLength)',
        Colors.orange,
      );
      return false;
    }

    return true;
  }

  Future<void> _saveVacancy() async {
    if (!_validateFields()) return;

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Preparando arquivos...';
      _uploadProgress = 0.0;
    });

    try {
      final (:imageUrls, :videoUrls) = await _uploadAllMedia();

      String finalSalary = 'A combinar';
      if (selectedSalaryType != null && selectedSalaryType != 'A combinar') {
        final salaryText = _salaryController.text.trim();
        finalSalary =
            salaryText.isNotEmpty ? salaryText : selectedSalaryType!;
      }

      setState(() => _uploadStatus = 'Salvando vaga...');

      final now = DateTime.now().toIso8601String();
      final titleText = _titleController.text.trim();

      final Map<String, dynamic> vacancyData = {
        'title': titleText.isNotEmpty ? titleText : selectedProfession!,
        'profession': selectedProfession,
        'state': selectedState,
        'city': selectedCity,
        'email_contact': widget.emailContact,
        'phone_contact': widget.phoneContact,
        'description': _descriptionController.text.trim(),
        'requests': [],
        'salary': finalSalary,
        'salary_type': selectedSalaryType ?? 'A combinar',
        'local_id': widget.localId,
        'midia': {
          'images': imageUrls,
          'videos': videoUrls,
        },
        'created_at': now,
        'updated_at': now,
        'status': 'Aberta',
        'views': {
          'request_views': {},
        },
        'stats': {
          'total_views': 0,
          'total_applications': 0,
          'created_timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      };

      final vacancyId = await _vacancyService.createVacancy(vacancyData);

      setState(() => _isUploading = false);

      if (vacancyId != null) {
        _showSnackBar('Vaga criada com sucesso!', Colors.green);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, vacancyId);
      } else {
        _showSnackBar('Erro ao criar vaga', Colors.red);
      }
    } catch (e) {
      debugPrint('Erro ao salvar vaga: $e');
      setState(() => _isUploading = false);
      _showSnackBar('Erro ao salvar vaga. Tente novamente.', Colors.red);
    }
  }

  void _viewImageFullscreen(File imageFile, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenMediaViewer(
          images: _selectedImages,
          initialIndex: initialIndex,
          isVideo: false,
        ),
      ),
    );
  }

  void _viewVideoFullscreen(File videoFile, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenMediaViewer(
          videos: _selectedVideos,
          initialIndex: initialIndex,
          isVideo: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          FocusScope.of(context).unfocus();
        });
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            widget.isEditing ? 'Editar Vaga' : 'Nova Vaga',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                      'Informações Básicas', Icons.assignment, true),
                  SizedBox(height: 16),

                  ProfessionDropdown(
                    initialValue: selectedProfession,
                    onChanged: (value) =>
                        setState(() => selectedProfession = value),
                  ),
                  SizedBox(height: 16),

                  _buildTextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    label: 'Título da Vaga (Opcional)',
                    hint: 'Ex: Vaga urgente para pedreiro experiente',
                    icon: Icons.title,
                  ),
                  SizedBox(height: 16),

                  _buildDescriptionField(),
                  SizedBox(height: 16),

                  StateDropdown(
                    initialValue: selectedState,
                    onChanged: (value) => setState(() {
                      selectedState = value;
                      selectedCity = null;
                    }),
                  ),
                  SizedBox(height: 16),

                  CityDropdown(
                    selectedState: selectedState,
                    initialValue: selectedCity,
                    onChanged: (value) =>
                        setState(() => selectedCity = value),
                  ),
                  SizedBox(height: 16),

                  _buildSalaryTypeDropdown(),
                  SizedBox(height: 16),

                  if (selectedSalaryType != null &&
                      selectedSalaryType != 'A combinar') ...[
                    _buildSalaryField(),
                    SizedBox(height: 16),
                  ],

                  SizedBox(height: 16),

                  _buildSectionTitle(
                      'Mídia (Opcional)', Icons.photo_library, false),
                  SizedBox(height: 16),
                  _buildMediaUploadSection(),
                  SizedBox(height: 16),

                  if (_selectedImages.isNotEmpty) ...[
                    _buildMediaGallery(
                      title: 'Imagens Selecionadas',
                      items: _selectedImages,
                      isVideo: false,
                    ),
                    SizedBox(height: 16),
                  ],

                  if (_selectedVideos.isNotEmpty) ...[
                    _buildMediaGallery(
                      title: 'Vídeos Selecionados',
                      items: _selectedVideos,
                      isVideo: true,
                    ),
                    SizedBox(height: 16),
                  ],

                  SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _saveVacancy,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isUploading
                            ? 'Salvando...'
                            : (widget.isEditing
                                ? 'Salvar Alterações'
                                : 'Criar Vaga'),
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),

            // Overlay de progresso
            if (_isUploading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: EdgeInsets.all(20),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: _uploadProgress > 0
                                ? _uploadProgress
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF6B35)),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _uploadStatus,
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          if (_uploadProgress > 0) ...[
                            SizedBox(height: 8),
                            Text(
                              '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Overlay de verificação de imagem
            if (_isCheckingImage)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF6B35)),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Verificando imagem...',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Garantindo que o conteúdo é seguro\npara nossa comunidade',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryTypeDropdown() {
    final bool isSelected = selectedSalaryType != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tipo de Contrato',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF374151),
              ),
            ),
            SizedBox(width: 6),
            Text('*', style: TextStyle(color: Colors.red, fontSize: 18)),
          ],
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              FocusScope.of(context).unfocus();
            });
            _showSalaryTypeDialog();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Color(0xFF3B82F6)
                    : Color(0xFFD1D5DB),
                width: isSelected ? 1.5 : 1,
              ),
              color: isSelected
                  ? Color(0xFFEFF6FF)
                  : Color(0xFFF9FAFB),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule,
                    color: isSelected
                        ? Color(0xFF3B82F6)
                        : Colors.grey[400],
                    size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedSalaryType ?? 'Selecione o tipo de contrato *',
                    style: TextStyle(
                      color: isSelected
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
        if (!isSelected) ...[
          SizedBox(height: 5),
          Text(
            'Obrigatório para publicar a vaga',
            style: TextStyle(fontSize: 11, color: Colors.red[400]),
          ),
        ],
      ],
    );
  }

  void _showSalaryTypeDialog() async {
    WidgetsBinding.instance
        .addPostFrameCallback((_) async => FocusScope.of(context).unfocus());

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF3B82F6),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'Tipo de Contrato',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: salaryTypes.length,
                    itemBuilder: (context, index) {
                      final type = salaryTypes[index];
                      final isSelected = type == selectedSalaryType;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedSalaryType = type;
                            if (type == 'A combinar')
                              _salaryController.clear();
                          });
                          Navigator.pop(dialogContext);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(0xFF3B82F6).withOpacity(0.1)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                  color: Colors.grey[200]!, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.attach_money,
                                  color: isSelected
                                      ? Color(0xFF3B82F6)
                                      : Colors.grey[600],
                                  size: 22),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  type,
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
                                Icon(Icons.check_circle,
                                    color: Color(0xFF3B82F6), size: 22),
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

    WidgetsBinding.instance
        .addPostFrameCallback((_) async => FocusScope.of(context).unfocus());
  }

  Widget _buildSalaryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Valor do Salário',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: _salaryController,
            focusNode: _salaryFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(),
            ],
            decoration: InputDecoration(
              hintText: 'R\$ 0,00',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.attach_money,
                  color: Color(0xFFFF6B35), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isRequired) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFFFF6B35), size: 22),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (isRequired) ...[
          SizedBox(width: 6),
          Text('*', style: TextStyle(color: Colors.red, fontSize: 18)),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon:
                  Icon(icon, color: Color(0xFFFF6B35), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    final int length = _descriptionController.text.trim().length;
    final bool tooShort = length > 0 && length < _descMinLength;
    final Color borderColor = tooShort
        ? Colors.orange
        : length >= _descMinLength
            ? Colors.green.shade400
            : Colors.grey[300]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Descrição',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(width: 6),
            Text('*', style: TextStyle(color: Colors.red, fontSize: 18)),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Descreva com detalhes os requisitos, responsabilidades e condições da vaga',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: TextField(
            controller: _descriptionController,
            focusNode: _descriptionFocus,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:
                  'Descreva os requisitos, responsabilidades, condições de trabalho e diferenciais da vaga...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon:
                  Icon(Icons.description, color: Color(0xFFFF6B35), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (tooShort)
              Text(
                'Mínimo de $_descMinLength caracteres',
                style: TextStyle(fontSize: 11, color: Colors.orange[700]),
              )
            else if (length >= _descMinLength)
              Row(children: [
                Icon(Icons.check_circle_outline,
                    size: 13, color: Colors.green.shade600),
                SizedBox(width: 4),
                Text('Ok',
                    style: TextStyle(
                        fontSize: 11, color: Colors.green.shade600)),
              ])
            else
              Text(
                'Mínimo $_descMinLength caracteres',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            Text(
              '$length/$_descMinLength',
              style: TextStyle(
                fontSize: 11,
                color: tooShort
                    ? Colors.orange[700]
                    : length >= _descMinLength
                        ? Colors.green.shade600
                        : Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaUploadSection() {
    final bool canAddMoreImages = _selectedImages.length < 3;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildUploadButton(
            Icons.photo_camera,
            canAddMoreImages
                ? 'Adicionar Fotos da Obra (${_selectedImages.length}/3)'
                : 'Limite de 3 fotos atingido',
            canAddMoreImages ? _pickImages : () {},
            enabled: canAddMoreImages,
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Máximo: 3 fotos por vaga',
                    style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: enabled ? Colors.grey[300]! : Colors.grey[200]!,
        ),
        borderRadius: BorderRadius.circular(10),
        color: enabled ? Colors.transparent : Colors.grey[100],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color:
                        enabled ? Color(0xFFFF6B35) : Colors.grey[400],
                    size: 22),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: enabled
                          ? Colors.grey[700]
                          : Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaGallery({
    required String title,
    required List<File> items,
    required bool isVideo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(isVideo ? Icons.videocam : Icons.photo,
                color: Color(0xFFFF6B35), size: 18),
            SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${items.length}',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Container(
                margin: EdgeInsets.only(right: 12),
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () => isVideo
                          ? _viewVideoFullscreen(items[index], index)
                          : _viewImageFullscreen(items[index], index),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: isVideo
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                        color: Colors.black,
                                        child: Center(
                                            child: Icon(Icons.videocam,
                                                size: 40,
                                                color: Colors.white70))),
                                    Icon(Icons.play_circle_fill,
                                        size: 50, color: Colors.white),
                                  ],
                                )
                              : Image.file(items[index], fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => isVideo
                            ? _removeVideo(index)
                            : _removeImage(index),
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}