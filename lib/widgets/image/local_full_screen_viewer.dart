import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Viewer de tela cheia para imagens e vídeos locais (File).
/// Substitui o FullscreenMediaViewer do components.dart.
///
/// Uso:
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => LocalFullscreenViewer(
///       files: _selectedImages,
///       initialIndex: index,
///       isVideo: false,
///     ),
///   ));
class LocalFullscreenViewer extends StatefulWidget {
  final List<File> files;
  final int initialIndex;
  final bool isVideo;

  const LocalFullscreenViewer({
    super.key,
    required this.files,
    required this.initialIndex,
    this.isVideo = false,
  });

  @override
  State<LocalFullscreenViewer> createState() => _LocalFullscreenViewerState();
}

class _LocalFullscreenViewerState extends State<LocalFullscreenViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Garante que a status bar fique visível com ícones brancos
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restaura o modo imersivo que o app usa globalmente
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
        overlays: []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Fundo preto — elimina o cinza
      backgroundColor: Colors.black,
      // ✅ extendBodyBehindAppBar para imagem ocupar tela cheia
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // ✅ Fundo semi-transparente para destacar o botão
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        // ✅ Botão de voltar sempre visível, branco
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Contador de itens (ex: "2 / 3")
        title: widget.files.length > 1
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.files.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: widget.isVideo
          ? _buildVideoPlaceholder()
          : _buildImagePageView(),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // IMAGENS — PageView com zoom via InteractiveViewer
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildImagePageView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.files.length,
      onPageChanged: (i) => setState(() => _currentIndex = i),
      itemBuilder: (context, index) {
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(
              widget.files[index],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // VÍDEOS — placeholder (adicione video_player se quiser reprodução)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildVideoPlaceholder() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.files.length,
      onPageChanged: (i) => setState(() => _currentIndex = i),
      itemBuilder: (context, index) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_fill,
                  size: 80, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                'Vídeo ${index + 1}',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Adicione o pacote video_player\npara reprodução inline',
                style: TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}