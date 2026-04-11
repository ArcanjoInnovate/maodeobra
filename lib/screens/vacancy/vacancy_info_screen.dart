// ignore_for_file: unused_import
import 'package:dartobra_new/services/badge/badge_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:dartobra_new/services/vacancy/vacancy_service.dart';
import 'edit_info_vacancy.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class InfoVacancy extends StatefulWidget {
  final String userPhone;
  final String userEmail;
  final String legalType;
  final String companyName;
  final String description;
  final String state;
  final String city;
  final String profession;
  final String status;
  final String title;
  final String salary;
  final String salaryType;
  final Map<dynamic, dynamic>? media;
  final List<dynamic>? requests;
  final String localId;
  final String vacancyId;

  const InfoVacancy({
    super.key,
    required this.userPhone,
    required this.legalType,
    required this.companyName,
    required this.description,
    required this.state,
    required this.city,
    required this.title,
    required this.profession,
    required this.status,
    required this.salary,
    required this.salaryType,
    this.media,
    this.requests,
    required this.vacancyId,
    required this.userEmail,
    required this.localId,
  });

  @override
  State<InfoVacancy> createState() => _InfoVacancyState();
}

class _InfoVacancyState extends State<InfoVacancy>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final VacancyService _vacancyService = VacancyService();
  List<Map<String, dynamic>> _candidates = [];
  bool _isLoadingCandidates = false;
  
  late String _currentStatus;
  late String _currentTitle;
  late String _currentProfession;
  late String _currentDescription;
  late String _currentState;
  late String _currentCity;
  late String _currentSalary;
  late String _currentSalaryType;
  late Map<dynamic, dynamic>? _currentMedia;
  
  List<String> _images = [];
  List<String> _videos = [];
  bool _hasMedia = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _currentStatus = widget.status;
    _currentTitle = widget.title;
    _currentProfession = widget.profession;
    _currentDescription = widget.description;
    _currentState = widget.state;
    _currentCity = widget.city;
    _currentSalary = widget.salary;
    _currentSalaryType = widget.salaryType;
    _currentMedia = widget.media;
    
    _loadMedia();
    _loadCandidates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reloadVacancyData() async {
    try {
      final snapshot = await _database.child('vacancy/${widget.vacancyId}').get();
      
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        
        setState(() {
          _currentTitle = data['title'] ?? widget.title;
          _currentProfession = data['profession'] ?? widget.profession;
          _currentDescription = data['description'] ?? widget.description;
          _currentState = data['state'] ?? widget.state;
          _currentCity = data['city'] ?? widget.city;
          _currentSalary = data['salary'] ?? widget.salary;
          _currentSalaryType = data['salary_type'] ?? widget.salaryType;
          _currentStatus = data['status'] ?? widget.status;
          _currentMedia = data['midia'];
          
          _images.clear();
          _videos.clear();
          _loadMedia();
        });
        
        print('✅ Dados da vaga recarregados');
      }
    } catch (e) {
      print('❌ Erro ao recarregar: $e');
    }
  }

  void _loadMedia() {
    if (_currentMedia != null) {
      if (_currentMedia!['images'] != null) {
        final imagesList = _currentMedia!['images'] as List;
        _images = imagesList.map((e) => e.toString()).toList();
      }
      
      if (_currentMedia!['videos'] != null) {
        final videosList = _currentMedia!['videos'] as List;
        _videos = videosList.map((e) => e.toString()).toList();
      }
      
      _hasMedia = _images.isNotEmpty || _videos.isNotEmpty;
    }
  }

  Future<void> _loadCandidates() async {
    if (widget.requests == null || widget.requests!.isEmpty) return;

    setState(() {
      _isLoadingCandidates = true;
    });

    try {
      final candidates = await _vacancyService.getCandidates(
        widget.vacancyId,
        widget.requests!,
      );
      
      setState(() {
        _candidates = candidates;
        _isLoadingCandidates = false;
      });
      
    } catch (e) {
      print('Erro ao carregar candidatos: $e');
      setState(() {
        _isLoadingCandidates = false;
      });
    }
  }

  Future<void> _toggleVacancyStatus() async {
    try {
      String newStatus = _currentStatus == 'Pausada' ? 'Aberta' : 'Pausada';
      
      await _vacancyService.updateVacancy(widget.vacancyId, {
        'status': newStatus,
      });
      
      setState(() {
        _currentStatus = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'Pausada' 
                ? 'Vaga pausada com sucesso' 
                : 'Vaga reativada com sucesso'
          ),
          backgroundColor: newStatus == 'Pausada' ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      print('Erro ao atualizar status: $e');
    }
  }

  Future<void> _deleteVacancy() async {
    try {
      if (_currentMedia != null) {
        if (_currentMedia!['images'] != null) {
          List<dynamic> images = _currentMedia!['images'];
          for (var imageUrl in images) {
            await _deleteFromCloudinary(imageUrl, 'image');
          }
        }
        
        if (_currentMedia!['videos'] != null) {
          List<dynamic> videos = _currentMedia!['videos'];
          for (var videoUrl in videos) {
            await _deleteFromCloudinary(videoUrl, 'video');
          }
        }
      }

      // 🔢 Conta quantos candidatos ainda não foram visualizados (badge pendente)
      int unreadCandidates = 0;
      try {
        final requestViewsSnap = await _database
            .child('vacancy/${widget.vacancyId}/views/request_views')
            .get();

        if (requestViewsSnap.exists) {
          final views = Map<String, dynamic>.from(requestViewsSnap.value as Map);
          for (final entry in views.values) {
            final viewData = Map<String, dynamic>.from(entry as Map);
            if (viewData['viewed_by_owner'] == false) {
              unreadCandidates++;
            }
          }
        }
      } catch (e) {
        print('⚠️ Erro ao contar candidatos não lidos: $e');
      }

      // 🗑️ Remove a vaga do banco
      await _database.child('vacancy/${widget.vacancyId}').remove();

      // 📉 Decrementa o badge pelo número de candidatos não lidos
      for (int i = 0; i < unreadCandidates; i++) {
        await BadgeHelper.decrementRequestBadge(widget.localId);
      }

      print('✅ Vaga excluída. $unreadCandidates badge(s) decrementado(s).');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vaga excluída com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      print('Erro ao excluir vaga: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir vaga'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteFromCloudinary(String mediaUrl, String resourceType) async {
    try {
      Uri uri = Uri.parse(mediaUrl);
      List<String> pathSegments = uri.pathSegments;
      
      int uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 2 >= pathSegments.length) {
        print('URL inválida: $mediaUrl');
        return;
      }
      
      String publicIdWithExtension = pathSegments.sublist(uploadIndex + 2).join('/');
      String publicId = publicIdWithExtension.substring(0, publicIdWithExtension.lastIndexOf('.'));
      
      const String cloudName = 'dsmgwupky';
      const String apiKey = '256987432736353';
      const String apiSecret = 'K8oSFMvqA6N2eU4zLTnLTVuArMU';
      
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
        
      String toSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      String signature = sha1.convert(utf8.encode(toSign)).toString();
      
      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/destroy'),
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'timestamp': timestamp.toString(),
          'signature': signature,
        },
      );
      
      if (response.statusCode == 200) {
        print('Mídia deletada: $publicId');
      } else {
        print('Erro ao deletar: ${response.body}');
      }
    } catch (e) {
      print('Erro ao deletar do Cloudinary: $e');
    }
  }

  Future<void> _rejectCandidate(String uid) async {
    try {
      print('🔍 Rejeitando candidato: $uid');

      List<dynamic> updatedRequests = List.from(widget.requests ?? []);
      updatedRequests.remove(uid);

      await _database
          .child('vacancy/${widget.vacancyId}/requests')
          .set(updatedRequests.isEmpty ? null : updatedRequests);

      await _database
          .child('vacancy/${widget.vacancyId}/views/request_views/$uid')
          .remove();

      print('📉 Decrementando badge...');
      await BadgeHelper.decrementRequestBadge(widget.localId);
      print('✅ Badge decrementado');

      setState(() {
        _candidates.removeWhere((candidate) => candidate['uid'] == uid);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Candidato recusado'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('❌ Erro ao recusar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao recusar candidato'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> remove_request(String uid) async {
    try {
      List<dynamic> updatedRequests = List.from(widget.requests ?? []);
      updatedRequests.remove(uid);

      await _database
          .child('vacancy/${widget.vacancyId}/requests')
          .set(updatedRequests.isEmpty ? null : updatedRequests);

      setState(() {
        _candidates.removeWhere((candidate) => candidate['uid'] == uid);
      });
    } catch (e) {
      print('Erro ao remover request: $e');
    }
  }

  Future<void> _approveCandidate(String employeeUid) async {
    try {
      print('🔍 Aprovando candidato: $employeeUid');

      final DatabaseReference chatRef = _database.child('Chats').push();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await chatRef.set({
        'contractor': widget.localId,
        'employee': employeeUid,
        'participants': {
          'contractor': 'offline',
          'employee': 'offline',
        },
        'metadata': {
          'created_at': timestamp,
          'last_message': '',
          'last_sender': '',
          'last_timestamp': timestamp,
        },
        'historical_messages': {
          'messages': {'init': true}
        },
        'unreadCount': {
          'contractor': 0,
          'employee': 0,
        }
      });

      print('✅ Chat criado: ${chatRef.key}');

      await _database
          .child('vacancy/${widget.vacancyId}/views/request_views/$employeeUid')
          .remove();

      await remove_request(employeeUid);

      print('📉 Decrementando badge...');
      await BadgeHelper.decrementRequestBadge(widget.localId);
      print('✅ Badge decrementado');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat iniciado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Erro ao aprovar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar chat'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageFullScreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(child: Image.network(imageUrl)),
          ),
        ),
      ),
    );
  }

  void _showVideoFullScreen(String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Detalhes da Vaga',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  icon: Icon(Icons.info_outline, size: 20),
                  text: 'Informações',
                ),
                Tab(
                  icon: Icon(Icons.people_outline, size: 20),
                  text: 'Candidatos',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildInfoTab(), _buildCandidatesTab()],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.lightBlue],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Vaga $_currentStatus',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  _currentProfession,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      '$_currentCity, $_currentState',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_hasMedia)
            Container(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _images.length + _videos.length,
                itemBuilder: (context, index) {
                  if (index < _images.length) {
                    final imageUrl = _images[index];
                    return Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _showImageFullScreen(imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            width: 160,
                            height: 188,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 160,
                                height: 188,
                                color: Colors.grey[300],
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey[600],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  } else {
                    final videoIndex = index - _images.length;
                    final videoUrl = _videos[videoIndex];
                    return Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _showVideoFullScreen(videoUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 160,
                            height: 188,
                            color: Colors.black87,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.videocam,
                                  size: 48,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    size: 32,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),

          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  title: 'Descrição da Vaga',
                  icon: Icons.description,
                  content: Text(
                    _currentDescription,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Salário',
                  icon: Icons.attach_money,
                  content: Column(
                    children: [
                      _buildInfoRow('Valor', _currentSalary),
                      SizedBox(height: 12),
                      _buildInfoRow('Frequência', _currentSalaryType),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Informações do Contratante',
                  icon: Icons.business,
                  content: Column(
                    children: [
                      if (widget.companyName.isNotEmpty) ...[
                        _buildInfoRow('Empresa', widget.companyName),
                        SizedBox(height: 12),
                      ],
                      _buildInfoRow(
                        'Tipo',
                        widget.legalType == 'pj'
                            ? 'Pessoa Jurídica (PJ)'
                            : 'Pessoa Física (PF)',
                      ),
                      SizedBox(height: 12),
                      _buildInfoRow('Email', widget.userEmail),
                      SizedBox(height: 12),
                      _buildInfoRow('Telefone', widget.userPhone),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditInfoVacancy(
                                isEditing: true,
                                localId: widget.localId,
                                emailContact: widget.userEmail,
                                phoneContact: widget.userPhone,
                                vacancyId: widget.vacancyId,
                                existingTitle: _currentTitle,
                                existingProfession: _currentProfession,
                                existingDescription: _currentDescription,
                                existingState: _currentState,
                                existingCity: _currentCity,
                                existingSalary: _currentSalary,
                                existingSalaryType: _currentSalaryType,
                                existingMedia: _currentMedia,
                              ),
                            ),
                          );
                          
                          if (result == true) {
                            await _reloadVacancyData();
                          }
                        },
                        icon: Icon(Icons.edit, size: 18),
                        label: Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleVacancyStatus,
                        icon: Icon(
                          _currentStatus == 'Pausada' 
                              ? Icons.play_circle 
                              : Icons.pause_circle,
                          size: 18,
                        ),
                        label: Text(
                          _currentStatus == 'Pausada' ? 'Reativar' : 'Pausar',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentStatus == 'Pausada'
                              ? Colors.green
                              : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Excluir vaga'),
                          content: Text(
                            'Tem certeza que deseja excluir esta vaga? Esta ação não pode ser desfeita.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteVacancy();
                              },
                              child: Text(
                                'Excluir',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: Icon(Icons.delete_outline, size: 18),
                    label: Text('Excluir Vaga'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red[300]!),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidatesTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                '${_candidates.length} ${_candidates.length == 1 ? 'candidato' : 'candidatos'}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_candidates.length} pendentes',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1),

        Expanded(
          child: _isLoadingCandidates
              ? Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                )
              : _candidates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Nenhum candidato ainda',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Os candidatos aparecerão aqui',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _candidates.length,
                  itemBuilder: (context, index) {
                    final candidate = _candidates[index];
                    return _buildCandidateCard(candidate);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCandidateCard(Map<String, dynamic> candidate) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFFFF6B35).withOpacity(0.1),
                  backgroundImage: candidate['avatar'] != null
                      ? NetworkImage(candidate['avatar'])
                      : null,
                  child: candidate['avatar'] == null
                      ? Text(
                          candidate['name'][0].toUpperCase(),
                          style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        candidate['phone'],
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Pendente',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(height: 1),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  '${candidate['city']}, ${candidate['state']}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Recusar candidato'),
                          content: Text(
                            'Tem certeza que deseja recusar este candidato?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _rejectCandidate(candidate['uid']);
                              },
                              child: Text(
                                'Recusar',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: Icon(Icons.close, size: 16),
                    label: Text('Recusar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveCandidate(candidate['uid']),
                    icon: Icon(Icons.check, size: 16),
                    label: Text('Aprovar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

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
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Erro ao carregar vídeo',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
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
        title: Text('Vídeo'),
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator(color: Color(0xFFFF6B35))
            : _hasError
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Erro ao carregar vídeo',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  )
                : _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : SizedBox(),
      ),
    );
  }
}