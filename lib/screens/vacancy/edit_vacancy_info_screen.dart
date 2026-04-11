// ✅ ARQUIVO CORRIGIDO - edit_info_vacancy.dart COM FIREBASE STORAGE
// CORREÇÕES:
//   1. Upload de imagens e vídeos em listas SEPARADAS desde o início,
//      eliminando a detecção por extensão na URL (que falha com Firebase Storage).
//   2. Validação de descrição mínima de 80 caracteres.
import 'package:dartobra_new/services/storage/moderation_image_service.dart';
import 'package:dartobra_new/services/storage/storage_service.dart';
import 'package:dartobra_new/services/vacancy/vacancy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'components.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';



class EditInfoVacancy extends StatefulWidget {
  final bool isEditing;
  final String emailContact;
  final String phoneContact;
  final String localId;

  final String? vacancyId;
  final String? existingTitle;
  final String? existingProfession;
  final String? existingDescription;
  final String? existingState;
  final String? existingCity;
  final String? existingSalary;
  final String? existingSalaryType;
  final Map<dynamic, dynamic>? existingMedia;

  EditInfoVacancy({
    this.isEditing = false,
    required this.emailContact,
    required this.phoneContact,
    required this.localId,
    required this.vacancyId,
    required this.existingTitle,
    required this.existingProfession,
    required this.existingDescription,
    required this.existingState,
    required this.existingCity,
    required this.existingSalary,
    required this.existingSalaryType,
    required this.existingMedia,
  });

  @override
  _EditInfoVacancyState createState() => _EditInfoVacancyState();
}

class _EditInfoVacancyState extends State<EditInfoVacancy> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();
  final VacancyService _vacancyService = VacancyService();
  final FirebaseStorageService _storageService = FirebaseStorageService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();

  final FocusNode _titleFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  final FocusNode _salaryFocus = FocusNode();

  String? selectedProfession;
  String? selectedSalaryType;
  String? selectedState;
  String? selectedCity;

  List<File> _selectedImages = [];
  List<File> _selectedVideos = [];
  List<String> _existingImageUrls = [];
  List<String> _existingVideoUrls = [];
  List<String> _urlsToDelete = [];

  bool _isUploading = false;
  bool _isCheckingImage = false;
  bool _isLoadingData = false;
  String _uploadStatus = '';
  double _uploadProgress = 0.0;

  // ── contador de caracteres para feedback visual ──────────────────────────
  int get _descLen => _descriptionController.text.trim().length;
  static const int _minDescLen = 80;

  final List<String> salaryTypes = [
    'Diário',
    'Semanal',
    'Quinzenal',
    'Mensal',
    'Por empreitada',
    'A combinar',
  ];

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() => setState(() {}));
    if (widget.isEditing) _loadExistingData();
  }

  void _loadExistingData() {
    setState(() => _isLoadingData = true);

    if (widget.existingTitle != null)       _titleController.text       = widget.existingTitle!;
    if (widget.existingDescription != null) _descriptionController.text = widget.existingDescription!;

    selectedProfession  = widget.existingProfession;
    selectedState       = widget.existingState;
    selectedCity        = widget.existingCity;
    selectedSalaryType  = widget.existingSalaryType;

    if (widget.existingSalary != null &&
        widget.existingSalary != 'A combinar' &&
        widget.existingSalaryType != 'A combinar') {
      _salaryController.text = widget.existingSalary!
          .replaceAll('R\$ ', '')
          .replaceAll('.', '')
          .replaceAll(',', '');
    }

    if (widget.existingMedia != null) {
      if (widget.existingMedia!['images'] != null) {
        _existingImageUrls = List<String>.from(widget.existingMedia!['images']);
      }
      if (widget.existingMedia!['videos'] != null) {
        _existingVideoUrls = List<String>.from(widget.existingMedia!['videos']);
      }
    }

    setState(() => _isLoadingData = false);
  }

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

  // ── FIX 1: upload separado por tipo — retorna (imageUrls, videoUrls) ──────
  Future<(List<String>, List<String>)> _uploadAllMedia() async {
    final List<String> uploadedImageUrls = [];
    final List<String> uploadedVideoUrls = [];

    final int total = _selectedImages.length + _selectedVideos.length;
    int current = 0;

    // Imagens
    for (final image in _selectedImages) {
      current++;
      setState(() {
        _uploadStatus  = 'Enviando imagem $current de $total...';
        _uploadProgress = 0.0;
      });

      final String? url = await _storageService.uploadImage(
        file: image,
        folder: 'vacancies',
        userId: widget.localId,
        quality: 70,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      if (url != null) {
        uploadedImageUrls.add(url);
      } else {
        _showSnackBar('Erro ao enviar imagem $current', Colors.red);
      }
    }

    // Vídeos
    for (final video in _selectedVideos) {
      current++;
      setState(() {
        _uploadStatus  = 'Enviando vídeo $current de $total...';
        _uploadProgress = 0.0;
      });

      final String? url = await _storageService.uploadVideo(
        file: video,
        folder: 'vacancies',
        userId: widget.localId,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      if (url != null) {
        uploadedVideoUrls.add(url);
      } else {
        _showSnackBar('Erro ao enviar vídeo $current', Colors.red);
      }
    }

    return (uploadedImageUrls, uploadedVideoUrls);
  }

  Future<void> _pickImages() async {
    try {
      final int total = _selectedImages.length + _existingImageUrls.length;
      if (total >= 3) {
        _showSnackBar('Você já adicionou o máximo de 3 fotos', Colors.orange);
        return;
      }
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final int remaining = 3 - total;
        final List<XFile> candidates = images.take(remaining).toList();

        for (final xfile in candidates) {
          final file = File(xfile.path);

          // ── Moderação via Vision API ──────────────────────────────────────
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
        }

        if (images.length > remaining) {
          _showSnackBar(
              'Apenas $remaining foto(s) podiam ser adicionadas. Limite: 3',
              Colors.orange);
        }
      }
    } catch (e) {
      setState(() => _isCheckingImage = false);
      _showSnackBar('Erro ao selecionar imagens', Colors.red);
    }
  }

  Future<void> _pickVideo() async {
    try {
      final int total = _selectedVideos.length + _existingVideoUrls.length;
      if (total >= 1) {
        _showSnackBar('Você já adicionou o máximo de 1 vídeo', Colors.orange);
        return;
      }
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) setState(() => _selectedVideos.add(File(video.path)));
    } catch (e) {
      _showSnackBar('Erro ao selecionar vídeo', Colors.red);
    }
  }

  void _removeImage(int index)         => setState(() => _selectedImages.removeAt(index));
  void _removeVideo(int index)         => setState(() => _selectedVideos.removeAt(index));

  void _removeExistingImage(int index) {
    final url = _existingImageUrls[index];
    setState(() { _existingImageUrls.removeAt(index); _urlsToDelete.add(url); });
  }

  void _removeExistingVideo(int index) {
    final url = _existingVideoUrls[index];
    setState(() { _existingVideoUrls.removeAt(index); _urlsToDelete.add(url); });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── FIX 2: validação com mínimo de 80 caracteres na descrição ─────────────
  bool _validateFields() {
    if (selectedProfession == null) {
      _showSnackBar('Selecione a profissão da vaga', Colors.orange);
      return false;
    }

    final desc = _descriptionController.text.trim();
    if (desc.isEmpty) {
      _showSnackBar('A descrição é obrigatória', Colors.orange);
      _descriptionFocus.requestFocus();
      return false;
    }
    if (desc.length < _minDescLen) {
      _showSnackBar(
        'A descrição precisa ter pelo menos $_minDescLen caracteres (${desc.length}/$_minDescLen)',
        Colors.orange,
      );
      _descriptionFocus.requestFocus();
      return false;
    }

    if (selectedState == null) {
      _showSnackBar('Selecione o estado', Colors.orange);
      return false;
    }
    if (selectedCity == null) {
      _showSnackBar('Selecione a cidade', Colors.orange);
      return false;
    }
    return true;
  }

  Future<void> _saveVacancy() async {
    if (!_validateFields()) return;

    setState(() {
      _isUploading    = true;
      _uploadStatus   = 'Preparando arquivos...';
      _uploadProgress = 0.0;
    });

    try {
      // ── FIX 1 em ação: recebe listas separadas por tipo ──────────────────
      final (newImageUrls, newVideoUrls) = await _uploadAllMedia();

      final List<String> finalImageUrls = [..._existingImageUrls, ...newImageUrls];
      final List<String> finalVideoUrls = [..._existingVideoUrls, ...newVideoUrls];

      // Processar salário
      String finalSalary = 'A combinar';
      if (selectedSalaryType != null && selectedSalaryType != 'A combinar') {
        final raw = _salaryController.text.trim();
        finalSalary = raw.isNotEmpty ? raw : selectedSalaryType!;
      }

      setState(() => _uploadStatus = 'Salvando vaga...');

      final Map<String, dynamic> vacancyData = {
        'title':         _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        'profession':    selectedProfession,
        'state':         selectedState,
        'city':          selectedCity,
        'email_contact': widget.emailContact,
        'phone_contact': widget.phoneContact,
        'description':   _descriptionController.text.trim(),
        'salary':        finalSalary,
        'salary_type':   selectedSalaryType,
        'local_id':      widget.localId,
        'midia': {
          'images': finalImageUrls,
          'videos': finalVideoUrls,
        },
      };

      if (widget.isEditing && widget.vacancyId != null) {
        await _database.child('vacancy/${widget.vacancyId}').update(vacancyData);

        if (_urlsToDelete.isNotEmpty) {
          setState(() => _uploadStatus = 'Limpando arquivos antigos...');
          for (final url in _urlsToDelete) {
            await _storageService.deleteFile(url);
          }
        }
        _showSnackBar('Vaga atualizada com sucesso!', Colors.green);
      } else {
        vacancyData['created_at'] = DateTime.now().toIso8601String();
        vacancyData['status']     = 'Aberta';
        vacancyData['requests']   = [];
        vacancyData['views']      = {'owner_last_viewed': null, 'request_views': {}};
        vacancyData['stats']      = {
          'total_views':         0,
          'unique_viewers':      [],
          'created_timestamp':   DateTime.now().millisecondsSinceEpoch,
          'total_applications':  0,
        };
        await _database.child('vacancy').push().set(vacancyData);
        _showSnackBar('Vaga criada com sucesso!', Colors.green);
      }

      setState(() => _isUploading = false);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      print('Erro ao salvar vaga: $e');
      setState(() => _isUploading = false);
      _showSnackBar('Erro ao salvar vaga. Tente novamente.', Colors.red);
    }
  }

  void _viewImageFullscreen(File imageFile, int initialIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FullscreenMediaViewer(
        images: _selectedImages, initialIndex: initialIndex, isVideo: false)));
  }

  void _viewVideoFullscreen(File videoFile, int initialIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FullscreenMediaViewer(
        videos: _selectedVideos, initialIndex: initialIndex, isVideo: true)));
  }

  void _viewExistingImageFullscreen(String imageUrl) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(child: InteractiveViewer(child: Image.network(imageUrl))))));
  }

  void _viewExistingVideoFullscreen(String videoUrl) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => VideoPlayerScreen(videoUrl: videoUrl)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(title: const Text('Carregando...'), backgroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            widget.isEditing ? 'Editar Vaga' : 'Nova Vaga',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Informações Básicas', Icons.assignment, true),
                  const SizedBox(height: 16),

                  ProfessionDropdown(
                    initialValue: selectedProfession,
                    onChanged: (value) => setState(() => selectedProfession = value),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    label: 'Título da Vaga (Opcional)',
                    hint: 'Ex: Vaga urgente para pedreiro experiente',
                    icon: Icons.title,
                  ),
                  const SizedBox(height: 16),

                  // ── Campo de descrição com contador de caracteres ──────────
                  _buildDescriptionField(),
                  const SizedBox(height: 16),

                  StateDropdown(
                    initialValue: selectedState,
                    onChanged: (value) => setState(() { selectedState = value; selectedCity = null; }),
                  ),
                  const SizedBox(height: 16),

                  CityDropdown(
                    selectedState: selectedState,
                    initialValue: selectedCity,
                    onChanged: (value) => setState(() => selectedCity = value),
                  ),
                  const SizedBox(height: 16),

                  _buildSalaryTypeDropdown(),
                  const SizedBox(height: 16),

                  if (selectedSalaryType != null && selectedSalaryType != 'A combinar') ...[
                    _buildSalaryField(),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 8),
                  _buildSectionTitle('Mídia (Opcional)', Icons.photo_library, false),
                  const SizedBox(height: 16),
                  _buildMediaUploadSection(),
                  const SizedBox(height: 16),

                  if (_existingImageUrls.isNotEmpty) ...[
                    _buildExistingMediaGallery(title: 'Imagens Atuais', items: _existingImageUrls, isVideo: false),
                    const SizedBox(height: 16),
                  ],
                  if (_existingVideoUrls.isNotEmpty) ...[
                    _buildExistingMediaGallery(title: 'Vídeos Atuais', items: _existingVideoUrls, isVideo: true),
                    const SizedBox(height: 16),
                  ],
                  if (_selectedImages.isNotEmpty) ...[
                    _buildMediaGallery(title: 'Novas Imagens', items: _selectedImages, isVideo: false),
                    const SizedBox(height: 16),
                  ],
                  if (_selectedVideos.isNotEmpty) ...[
                    _buildMediaGallery(title: 'Novos Vídeos', items: _selectedVideos, isVideo: true),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _saveVacancy,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _isUploading
                            ? 'Salvando...'
                            : (widget.isEditing ? 'Salvar Alterações' : 'Criar Vaga'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Overlay de progresso
            if (_isUploading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(20),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: _uploadProgress > 0 ? _uploadProgress : null,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(_uploadStatus,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center),
                          if (_uploadProgress > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  // ── Campo de descrição com contador e barra de progresso ──────────────────
  Widget _buildDescriptionField() {
    final bool reached = _descLen >= _minDescLen;
    final double progress = (_descLen / _minDescLen).clamp(0.0, 1.0);
    final Color barColor = reached
        ? const Color(0xFF22C55E)
        : (_descLen > _minDescLen * 0.6 ? Colors.orange : Colors.red.shade300);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Descrição *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            // contador XX/80
            Text(
              '$_descLen / $_minDescLen',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: reached ? const Color(0xFF22C55E) : Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: reached
                  ? const Color(0xFF22C55E)
                  : (_descLen > 0 ? Colors.orange.shade200 : Colors.grey.shade300),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _descriptionController,
            focusNode: _descriptionFocus,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Descreva os requisitos, responsabilidades e condições da vaga...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(bottom: 68),
                child: Icon(Icons.description, color: const Color(0xFFFF6B35), size: 20)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Barra de progresso visual
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        if (!reached && _descLen > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Faltam ${_minDescLen - _descLen} caracteres para o mínimo',
            style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
          ),
        ],
      ],
    );
  }

  Widget _buildSalaryTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de Salário (Opcional)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF374151))),
        const SizedBox(height: 8),
        InkWell(
          onTap: () { FocusScope.of(context).unfocus(); _showSalaryTypeDialog(); },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
              color: const Color(0xFFF9FAFB),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.grey[400], size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedSalaryType ?? 'Selecione o tipo de salário',
                    style: TextStyle(
                      color: selectedSalaryType != null ? const Color(0xFF1F2937) : Colors.grey[400],
                      fontSize: 16),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSalaryTypeDialog() async {
    FocusScope.of(context).unfocus();
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20), topRight: Radius.circular(20))),
                  child: Row(children: [
                    const Icon(Icons.schedule, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text('Tipo de Salário',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                ),
                Flexible(
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
                            if (type == 'A combinar') _salaryController.clear();
                          });
                          Navigator.pop(dialogContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.transparent,
                            border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1))),
                          child: Row(children: [
                            Icon(Icons.attach_money,
                              color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[600], size: 22),
                            const SizedBox(width: 16),
                            Expanded(child: Text(type,
                              style: TextStyle(
                                fontSize: 16,
                                color: isSelected ? const Color(0xFF3B82F6) : Colors.black87,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 22),
                          ]),
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
    FocusScope.of(context).unfocus();
  }

  Widget _buildSalaryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Valor do Salário',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!)),
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
              prefixIcon: const Icon(Icons.attach_money, color: Color(0xFFFF6B35), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isRequired) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF6B35), size: 22),
        const SizedBox(width: 8),
        Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        if (isRequired) ...[
          const SizedBox(width: 6),
          const Text('*', style: TextStyle(color: Colors.red, fontSize: 18)),
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
        Text(label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!)),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(icon, color: const Color(0xFFFF6B35), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaUploadSection() {
    final int totalImages = _selectedImages.length + _existingImageUrls.length;
    final int totalVideos = _selectedVideos.length + _existingVideoUrls.length;
    final bool canAddImages = totalImages < 3;
    final bool canAddVideo  = totalVideos < 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildUploadButton(
            Icons.photo_camera,
            canAddImages
                ? 'Adicionar Fotos da Obra ($totalImages/3)'
                : 'Limite de 3 fotos atingido',
            canAddImages ? _pickImages : () {},
            enabled: canAddImages,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(child: Text('Máximo: 3 fotos por vaga',
                style: TextStyle(fontSize: 12, color: Colors.blue[900]))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(IconData icon, String label, VoidCallback onTap, {bool enabled = true}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: enabled ? Colors.grey[300]! : Colors.grey[200]!,
          style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(10),
        color: enabled ? Colors.transparent : Colors.grey[100],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: enabled ? const Color(0xFFFF6B35) : Colors.grey[400], size: 22),
              const SizedBox(width: 10),
              Flexible(child: Text(label,
                style: TextStyle(
                  color: enabled ? Colors.grey[700] : Colors.grey[400],
                  fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildExistingMediaGallery({
    required String title,
    required List<String> items,
    required bool isVideo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(isVideo ? Icons.videocam : Icons.photo, color: Colors.blue[700], size: 18),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.blue[700], borderRadius: BorderRadius.circular(10)),
            child: Text('${items.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: Stack(children: [
                  GestureDetector(
                    onTap: () => isVideo
                        ? _viewExistingVideoFullscreen(items[index])
                        : _viewExistingImageFullscreen(items[index]),
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[300]!, width: 2)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: isVideo
                            ? Stack(alignment: Alignment.center, children: [
                                Container(color: Colors.black,
                                  child: const Center(child: Icon(Icons.videocam, size: 40, color: Colors.white70))),
                                const Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
                              ])
                            : Image.network(items[index], fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: Icon(Icons.broken_image, size: 40, color: Colors.grey[600]))),
                      ),
                    ),
                  ),
                  Positioned(top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => isVideo ? _removeExistingVideo(index) : _removeExistingImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                ]),
              );
            },
          ),
        ),
      ],
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
        Row(children: [
          Icon(isVideo ? Icons.videocam : Icons.photo, color: const Color(0xFFFF6B35), size: 18),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
            child: Text('${items.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: Stack(children: [
                  GestureDetector(
                    onTap: () => isVideo
                        ? _viewVideoFullscreen(items[index], index)
                        : _viewImageFullscreen(items[index], index),
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: isVideo
                            ? Stack(alignment: Alignment.center, children: [
                                Container(color: Colors.black,
                                  child: const Center(child: Icon(Icons.videocam, size: 40, color: Colors.white70))),
                                const Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
                              ])
                            : Image.file(items[index], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Positioned(top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => isVideo ? _removeVideo(index) : _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── VideoPlayerScreen ─────────────────────────────────────────────────────────
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError  = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
      );
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() { _isLoading = false; _hasError = true; });
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Vídeo'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Color(0xFFFF6B35))
            : _hasError
                ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.white),
                    SizedBox(height: 16),
                    Text('Erro ao carregar vídeo',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  ])
                : _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const SizedBox(),
      ),
    );
  }
}