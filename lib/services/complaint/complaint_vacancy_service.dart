import 'package:firebase_database/firebase_database.dart';

class ComplaintService {
  final DatabaseReference _database =
      FirebaseDatabase.instance.ref().child('complaints');

  Future<void> createComplaint({
    required String chatId,
    required String reportId,
    required String reportedId,
    required String reason,
    required String severity,
    required String description,
  }) async {
    try {
      final newComplaintRef = _database.push();

      await newComplaintRef.set({
        'type': 'vacancy',
        'vacancy_id': chatId,
        'report_id': reportId,
        'reported_id': reportedId,
        'reason': reason,
        'severity': severity,
        'description': description,
        'status': 'pending', // pending | reviewed | resolved
        'created_at': ServerValue.timestamp,
      });

      print('✅ Denúncia criada com sucesso');
    } catch (e) {
      print('❌ Erro ao criar denúncia: $e');
      rethrow;
    }
  }
}
