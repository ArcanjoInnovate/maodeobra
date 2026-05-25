import 'package:dartobra_new/services/cache/profile_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';


class EditContactPhoneScreen extends StatefulWidget {
  final String local_id;
  final String email_contact;
  final String userPhone;

  const EditContactPhoneScreen({
    super.key,
    required this.local_id,
    required this.email_contact,
    required this.userPhone,
  });

  @override
  State<EditContactPhoneScreen> createState() => _EditContactPhoneScreenState();
}

class _EditContactPhoneScreenState extends State<EditContactPhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isSaving = false;

  bool get _phoneIsDefined {
    final p = widget.userPhone.trim().toLowerCase();
    return p.isNotEmpty && p != 'não definido' && p != 'nao definido';
  }

  @override
  void initState() {
    super.initState();
    if (_phoneIsDefined) {
      _phoneController.text = widget.userPhone;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhone(String phone) {
    String numbers = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.length <= 2) return numbers;
    if (numbers.length <= 7) {
      return '(${numbers.substring(0, 2)}) ${numbers.substring(2)}';
    }
    if (numbers.length <= 11) {
      return '(${numbers.substring(0, 2)}) ${numbers.substring(2, numbers.length - 4)}-${numbers.substring(numbers.length - 4)}';
    }
    return '(${numbers.substring(0, 2)}) ${numbers.substring(2, 7)}-${numbers.substring(7, 11)}';
  }

  Future<bool> _checkPhoneExists(String phone) async {
    try {
      return await ValidationCache.checkPhoneExists(
        phone: phone,
        currentUserId: widget.local_id,
        database: FirebaseDatabase.instance.ref(),
      );
    } catch (e) {
      debugPrint('❌ Erro ao verificar telefone: $e');
      throw Exception('Erro ao verificar telefone');
    }
  }

  Future<void> _savePhoneToFirebase(String phone) async {
    try {
      String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      
      Map<String, dynamic> updateData = {
        'telefone': cleanPhone,
      };

      if (widget.email_contact.isNotEmpty && 
          widget.email_contact.toLowerCase() != 'não definido' &&
          widget.email_contact != 'Não definido') {
        updateData['finished_contact'] = true;
      }

      await FirebaseDatabase.instance
          .ref()
          .child('Users')
          .child(widget.local_id)
          .update(updateData);
      
      debugPrint('✅ Telefone salvo no Firebase: $cleanPhone');
    } catch (e) {
      debugPrint('❌ Erro ao salvar telefone no Firebase: $e');
      throw Exception('Erro ao salvar telefone');
    }
  }

  Future<void> _savePhone() async {
    String phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.length < 10) {
      _showSnackBar('Digite um telefone válido com DDD', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      bool phoneExists = await _checkPhoneExists(phone);
      
      if (phoneExists) {
        setState(() => _isSaving = false);
        _showSnackBar('Este telefone já está sendo usado por outro usuário', isError: true);
        return;
      }

      await _savePhoneToFirebase(phone);
      ValidationCache.invalidatePhone(widget.userPhone);

      setState(() => _isSaving = false);
      _showSnackBar('Telefone atualizado com sucesso!', isError: false);

      await Future.delayed(const Duration(milliseconds: 800));
      
      if (mounted) {
        Navigator.pop(context, _formatPhone(phone));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      
      String errorMessage = 'Erro ao salvar telefone. Tente novamente.';
      if (e.toString().contains('connection')) {
        errorMessage = 'Erro de conexão. Verifique sua internet.';
      }
      _showSnackBar(errorMessage, isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2D3142)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Editar Telefone',
            style: TextStyle(color: Color(0xFF2D3142), fontSize: 20, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.04),

                Container(
                  width: screenWidth * 0.25,
                  height: screenWidth * 0.25,
                  decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                  child: Icon(Icons.phone_android, size: screenWidth * 0.13, color: Colors.blue[700]),
                ),

                SizedBox(height: screenHeight * 0.03),

                Text(
                  'Atualizar Telefone',
                  style: TextStyle(
                    fontSize: screenHeight * 0.032,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),

                SizedBox(height: screenHeight * 0.012),

                Text(
                  'Digite seu novo número de telefone',
                  style: TextStyle(fontSize: screenHeight * 0.018, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: screenHeight * 0.04),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  onChanged: (value) {
                    final formatted = _formatPhone(value);
                    _phoneController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: '(00) 00000-0000',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    prefixIcon: Icon(Icons.phone, color: Colors.blue[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),

                SizedBox(height: screenHeight * 0.03),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _savePhone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Salvar Telefone',
                                style: TextStyle(
                                  fontSize: screenHeight * 0.02,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                SizedBox(height: screenHeight * 0.02),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'O telefone não pode estar em uso por outro usuário',
                          style: TextStyle(fontSize: screenHeight * 0.015, color: Colors.blue[900]),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }
}