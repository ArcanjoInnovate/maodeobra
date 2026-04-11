import 'dart:io';
import 'package:dartobra_new/services/services_storage/service_moderation_image.dart';
import 'package:dartobra_new/services/services_storage/service_storage.dart';
import 'package:dartobra_new/widgets/permissions/permissions_utils.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dartobra_new/screens/app_home/edit_principal_profile/components.dart';


class EditBasicInfoScreen extends StatefulWidget {
  final String local_id;
  final String userName;
  final String userEmail;
  final bool finished_basic;
  final String userPhone;
  final String userCity;
  final String userState;
  final int userAge;
  final String userAvatar;
  final String legalType;
  final String company;
  final String activeMode;
  final String profession;
  final String summary;
  final List<String> skills;
  final Map<String, dynamic> dataWorker;
  final Map<String, dynamic> dataContractor;

  EditBasicInfoScreen({
    required this.local_id,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.userCity,
    required this.userState,
    required this.finished_basic,
    required this.userAge,
    required this.userAvatar,
    required this.legalType,
    required this.company,
    required this.dataWorker,
    required this.dataContractor,
    required this.activeMode,
    required this.profession,
    required this.summary,
    required this.skills,
  });

  @override
  _EditBasicInfoScreenState createState() => _EditBasicInfoScreenState();
}

class _EditBasicInfoScreenState extends State<EditBasicInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorageService _storageService = FirebaseStorageService();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _dummyFocus = FocusNode();

  String? selectedState;
  String? selectedCity;
  File? _profileImage;
  String? _currentAvatarUrl;
  String? _oldAvatarUrl;
  bool _isSaving = false;
  bool _isCheckingImage = false;
  double _uploadProgress = 0.0;

  bool _nameIsDefined(String name) {
    final n = name.trim().toLowerCase();
    return n.isNotEmpty && n != 'não definido' && n != 'nao definido';
  }

  @override
  void initState() {
    super.initState();
    // ✅ Só preenche o nome se ele for um valor real
    if (_nameIsDefined(widget.userName)) {
      _nameController.text = widget.userName;
    }
    _ageController.text = widget.userAge > 0 ? widget.userAge.toString() : '';
    selectedState = widget.userState.isNotEmpty ? widget.userState : null;
    selectedCity = widget.userCity.isNotEmpty ? widget.userCity : null;
    _currentAvatarUrl = widget.userAvatar.isNotEmpty ? widget.userAvatar : null;
    _oldAvatarUrl = _currentAvatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _nameFocus.dispose();
    _dummyFocus.dispose();
    super.dispose();
  }

  void _removeFocusCompletely() {
    _nameFocus.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    Future.delayed(const Duration(milliseconds: 10), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_dummyFocus);
        Future.delayed(const Duration(milliseconds: 10), () {
          if (mounted) {
            _dummyFocus.unfocus();
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          }
        });
      }
    });
  }

  Future<void> _showImageSourceModal() async {
    _removeFocusCompletely();
    await Future.delayed(const Duration(milliseconds: 100));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue, size: 28),
              title: const Text('Tirar Foto', style: TextStyle(fontSize: 16)),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromSource(ImageSource.camera);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue, size: 28),
              title: const Text('Escolher da Galeria', style: TextStyle(fontSize: 16)),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromSource(ImageSource.gallery);
              },
            ),
            if (_profileImage != null || _currentAvatarUrl != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red, size: 28),
                title: const Text('Remover Foto', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _profileImage = null;
                    _currentAvatarUrl = null;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    ).then((_) => _removeFocusCompletely());
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    final bool isCamera = source == ImageSource.camera;
    final String label = isCamera ? 'câmera' : 'galeria';
    final String reason = isCamera
        ? 'para tirar sua foto de perfil'
        : 'para escolher sua foto de perfil';

    var result = await PermissionUtil.checkAndRequest(isCamera: isCamera);

    if (result == PermissionResult.denied) {
      final wantsToRetry = await PermissionUtil.showPermissionDialog(
        context: context,
        result: result,
        permissionLabel: label,
        usageReason: reason,
      );
      if (!wantsToRetry) return;
      result = await PermissionUtil.checkAndRequest(isCamera: isCamera);
    }

    if (result != PermissionResult.granted) {
      await PermissionUtil.showPermissionDialog(
        context: context,
        result: result,
        permissionLabel: label,
        usageReason: reason,
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        final file = File(image.path);

        setState(() => _isCheckingImage = true);
        final approved = await checkAndShowModerationDialog(
          context,
          file,
          onCheckEnd: () => setState(() => _isCheckingImage = false),
        );
        setState(() => _isCheckingImage = false);

        if (!mounted) return;

        if (approved) {
          setState(() {
            _profileImage = file;
            _currentAvatarUrl = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
      setState(() => _isCheckingImage = false);
      _showSnackBar('Erro ao selecionar imagem', isError: true);
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Digite seu nome', isError: true);
      return;
    }
    if (_ageController.text.trim().isEmpty) {
      _showSnackBar('Digite sua idade', isError: true);
      return;
    }

    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 18 || age > 120) {
      _showSnackBar('Digite uma idade válida (18-120)', isError: true);
      return;
    }

    if (selectedState == null || selectedCity == null) {
      _showSnackBar('Selecione estado e cidade', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadProgress = 0.0;
    });

    try {
      String? avatarUrl = _currentAvatarUrl;
      bool shouldDeleteOldImage = false;
      String? oldImageToDelete;

      if (_profileImage != null) {
        _showSnackBar('Fazendo upload da imagem...', isError: false);

        avatarUrl = await _storageService.uploadImage(
          file: _profileImage!,
          folder: 'profiles',
          userId: widget.local_id,
          quality: 70,
          onProgress: (progress) {
            setState(() => _uploadProgress = progress);
          },
        );

        if (avatarUrl == null) {
          final shouldContinue = await _showConfirmDialog(
            'Erro no Upload',
            'Não foi possível fazer upload da imagem. Deseja salvar sem atualizar a foto?',
          );
          if (!shouldContinue) {
            setState(() => _isSaving = false);
            return;
          }
          avatarUrl = _currentAvatarUrl;
        } else {
          if (_oldAvatarUrl != null && _oldAvatarUrl!.isNotEmpty) {
            shouldDeleteOldImage = true;
            oldImageToDelete = _oldAvatarUrl;
          }
        }
      } else if (_currentAvatarUrl == null &&
          _oldAvatarUrl != null &&
          _oldAvatarUrl!.isNotEmpty) {
        shouldDeleteOldImage = true;
        oldImageToDelete = _oldAvatarUrl;
      }

      final updates = {
        'Name': _nameController.text.trim(),
        'age': age,
        'city': selectedCity,
        'state': selectedState,
        'finished_basic': true,
        'avatar': (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : '',
      };

      await _database.child('Users').child(widget.local_id).update(updates);

      if (shouldDeleteOldImage && oldImageToDelete != null) {
        debugPrint('🗑️ Deletando imagem antiga...');
        await _storageService.deleteFile(oldImageToDelete);
      }

      _showSnackBar('Informações atualizadas com sucesso!', isError: false);
      await Future.delayed(const Duration(milliseconds: 800));

      final updatedData = {
        'name': _nameController.text.trim(),
        'age': age,
        'city': selectedCity,
        'state': selectedState,
        'avatar': avatarUrl ?? '',
        'finished_basic': true,
      };

      Navigator.pop(context, updatedData);
    } catch (e) {
      debugPrint('Erro ao salvar: $e');
      _showSnackBar('Erro ao salvar alterações. Tente novamente.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continuar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Informações Básicas',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Focus(
                    focusNode: _dummyFocus,
                    child: const SizedBox(width: 0, height: 0),
                  ),

                  // Foto de perfil
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceModal,
                          child: Container(
                            width: screenWidth * 0.35,
                            height: screenWidth * 0.35,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              border: Border.all(
                                color: const Color(0xFF3B82F6).withOpacity(0.3),
                                width: 2,
                              ),
                              image: _profileImage != null
                                  ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover)
                                  : _currentAvatarUrl != null
                                      ? DecorationImage(image: NetworkImage(_currentAvatarUrl!), fit: BoxFit.cover)
                                      : null,
                            ),
                            child: (_profileImage == null && _currentAvatarUrl == null)
                                ? const Icon(Icons.person, size: 60, color: Color(0xFF3B82F6))
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showImageSourceModal,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'Nome Completo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    decoration: InputDecoration(
                      hintText: 'Digite seu nome',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Idade',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 8),
                  AgeTextField(controller: _ageController),

                  const SizedBox(height: 20),

                  Listener(
                    onPointerDown: (_) => _removeFocusCompletely(),
                    child: StateDropdown(
                      initialValue: selectedState,
                      onChanged: (value) {
                        _removeFocusCompletely();
                        setState(() {
                          selectedState = value;
                          selectedCity = null;
                        });
                        Future.delayed(const Duration(milliseconds: 100), _removeFocusCompletely);
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  Listener(
                    onPointerDown: (_) => _removeFocusCompletely(),
                    child: CityDropdown(
                      selectedState: selectedState,
                      initialValue: selectedCity,
                      onChanged: (value) {
                        _removeFocusCompletely();
                        setState(() => selectedCity = value);
                        Future.delayed(const Duration(milliseconds: 100), _removeFocusCompletely);
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        disabledBackgroundColor: const Color(0xFF3B82F6).withOpacity(0.6),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Salvar Alterações',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isSaving && _uploadProgress > 0)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: _uploadProgress,
                            color: const Color(0xFF3B82F6),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text('Enviando: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (_isCheckingImage)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          const Text('Verificando imagem...',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(
                            'Garantindo que o conteúdo é seguro\npara nossa comunidade',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
}