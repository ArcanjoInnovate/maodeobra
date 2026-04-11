import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Faz upload de uma imagem com compressão automática
  /// 
  /// [file] - Arquivo de imagem a ser enviado
  /// [folder] - Pasta no Firebase Storage (ex: 'profiles', 'vacancies')
  /// [userId] - ID do usuário (opcional, para organização)
  /// [quality] - Qualidade da compressão (0-100, padrão 70)
  /// 
  /// Retorna a URL de download ou null em caso de erro
  Future<String?> uploadImage({
    required File file,
    required String folder,
    String? userId,
    int quality = 70,
    Function(double)? onProgress,
  }) async {
    try {
      File fileToUpload;
      bool wasCompressed = false;

      // Tentar comprimir imagem
      final compressedFile = await _compressImage(file, quality);
      
      if (compressedFile != null) {
        fileToUpload = compressedFile;
        wasCompressed = true;
        print('✅ Usando imagem comprimida');
      } else {
        // Fallback: usar imagem original se compressão falhar
        print('⚠️ Compressão falhou, usando imagem original');
        fileToUpload = file;
        wasCompressed = false;
      }

      // Gerar nome único com extensão apropriada
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = wasCompressed ? '.jpg' : path.extension(file.path);
      final fileName = '${timestamp}_${_generateRandomString()}$extension';

      // Definir caminho no Storage
      String storagePath = userId != null 
          ? '$folder/$userId/$fileName'
          : '$folder/$fileName';

      // Determinar content type
      String contentType = 'image/jpeg';
      if (!wasCompressed) {
        final ext = path.extension(file.path).toLowerCase();
        if (ext == '.png') contentType = 'image/png';
        else if (ext == '.webp') contentType = 'image/webp';
        else if (ext == '.gif') contentType = 'image/gif';
      }

      print('📤 Fazendo upload para: $storagePath');

      // Obter tamanhos antes do upload
      final originalSize = file.lengthSync();
      final uploadSize = fileToUpload.lengthSync();

      // Upload
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(
        fileToUpload,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'compressed': wasCompressed.toString(),
            'originalSize': originalSize.toString(),
            'uploadedSize': uploadSize.toString(),
          },
        ),
      );

      // Monitorar progresso
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((taskSnapshot) {
          final progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
          onProgress(progress);
        });
      }

      // Aguardar conclusão
      await uploadTask;

      // Obter URL de download
      final downloadUrl = await ref.getDownloadURL();
      
      // Deletar arquivo temporário comprimido (se foi criado)
      if (wasCompressed && await fileToUpload.exists()) {
        try {
          await fileToUpload.delete();
          print('🗑️ Arquivo temporário deletado');
        } catch (e) {
          print('⚠️ Erro ao deletar temporário: $e');
        }
      }
      
      print('✅ Imagem enviada com sucesso!');
      print('📊 Tamanho original: ${_formatBytes(originalSize)}');
      print('📊 Tamanho enviado: ${_formatBytes(uploadSize)}');
      if (wasCompressed) {
        final reduction = ((originalSize - uploadSize) / originalSize * 100);
        print('💾 Economia: ${reduction.toStringAsFixed(1)}%');
      }
      
      return downloadUrl;
      
    } catch (e) {
      print('❌ Erro ao fazer upload de imagem: $e');
      return null;
    }
  }

  /// Faz upload de um vídeo com compressão automática
  /// 
  /// [file] - Arquivo de vídeo a ser enviado
  /// [folder] - Pasta no Firebase Storage
  /// [userId] - ID do usuário (opcional)
  /// [quality] - Qualidade de compressão (low, medium, high, default)
  /// 
  /// Retorna a URL de download ou null em caso de erro
  Future<String?> uploadVideo({
    required File file,
    required String folder,
    String? userId,
    VideoQuality quality = VideoQuality.MediumQuality,
    Function(double)? onProgress,
  }) async {
    try {
      print('🎥 Iniciando compressão de vídeo...');
      
      // Comprimir vídeo
      final compressedFile = await _compressVideo(file, quality);
      if (compressedFile == null) {
        print('❌ Erro ao comprimir vídeo');
        return null;
      }

      // Gerar nome único
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(file.path);
      final fileName = '${timestamp}_${_generateRandomString()}$extension';

      // Definir caminho no Storage
      String storagePath = userId != null 
          ? '$folder/$userId/$fileName'
          : '$folder/$fileName';

      print('📤 Enviando vídeo para: $storagePath');

      // Upload
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(
        File(compressedFile.path!),
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'compressed': 'true',
            'originalSize': file.lengthSync().toString(),
            'compressedSize': File(compressedFile.path!).lengthSync().toString(),
          },
        ),
      );

      // Monitorar progresso
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((taskSnapshot) {
          final progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
          onProgress(progress);
        });
      }

      // Aguardar conclusão
      await uploadTask;

      // Obter URL de download
      final downloadUrl = await ref.getDownloadURL();
      
      // Deletar arquivo temporário comprimido
      await VideoCompress.deleteAllCache();
      
      print('✅ Vídeo enviado com sucesso: $downloadUrl');
      print('📊 Tamanho original: ${_formatBytes(file.lengthSync())}');
      print('📊 Tamanho comprimido: ${_formatBytes(File(compressedFile.path!).lengthSync())}');
      
      return downloadUrl;
      
    } catch (e) {
      print('❌ Erro ao fazer upload de vídeo: $e');
      await VideoCompress.deleteAllCache();
      return null;
    }
  }

  /// Deleta um arquivo do Firebase Storage pela URL
  /// 
  /// [url] - URL do arquivo no Firebase Storage
  /// 
  /// Retorna true se deletado com sucesso
  Future<bool> deleteFile(String url) async {
    try {
      // Extrair o caminho do arquivo da URL
      final ref = _storage.refFromURL(url);
      await ref.delete();
      
      print('🗑️ Arquivo deletado com sucesso: ${ref.fullPath}');
      return true;
      
    } catch (e) {
      print('❌ Erro ao deletar arquivo: $e');
      return false;
    }
  }

  /// Deleta múltiplos arquivos
  /// 
  /// [urls] - Lista de URLs a serem deletadas
  /// 
  /// Retorna número de arquivos deletados com sucesso
  Future<int> deleteMultipleFiles(List<String> urls) async {
    int successCount = 0;
    
    for (final url in urls) {
      final success = await deleteFile(url);
      if (success) successCount++;
    }
    
    print('🗑️ $successCount de ${urls.length} arquivos deletados');
    return successCount;
  }

  // ============== MÉTODOS PRIVADOS ==============

  /// Comprime uma imagem usando flutter_image_compress
  Future<File?> _compressImage(File file, int quality) async {
    try {
      final dir = await getTemporaryDirectory();
      
      // ✅ CORRIGIDO: Sempre usar .jpg para formato JPEG
      // O flutter_image_compress exige que o nome termine com .jpg ou .jpeg
      // quando o formato é CompressFormat.jpeg
      final targetPath = path.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      print('📝 Comprimindo imagem...');
      print('   Original: ${file.path}');
      print('   Destino: $targetPath');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        print('⚠️ Compressão retornou null');
        return null;
      }

      // Verificar se o arquivo realmente existe
      final compressedFile = File(result.path);
      if (!await compressedFile.exists()) {
        print('❌ Arquivo comprimido não existe: ${result.path}');
        return null;
      }

      print('✅ Imagem comprimida com sucesso');
      print('   Tamanho: ${await compressedFile.length()} bytes');
      
      return compressedFile;
      
    } catch (e) {
      print('❌ Erro ao comprimir imagem: $e');
      return null;
    }
  }

  /// Comprime um vídeo usando video_compress
  Future<MediaInfo?> _compressVideo(File file, VideoQuality quality) async {
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );
      
      return info;
      
    } catch (e) {
      print('❌ Erro ao comprimir vídeo: $e');
      return null;
    }
  }

  /// Gera uma string aleatória para nomes de arquivo únicos
  String _generateRandomString([int length = 8]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) => chars[(random + index) % chars.length]).join();
  }

  /// Formata bytes em KB, MB, etc
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}