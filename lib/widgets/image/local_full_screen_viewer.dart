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
        // ✅ Botão de voltar sempre visível, branco
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Contador de itens (ex: "2 / 3")
        title: widget.files.length > 1
            ? Text(
                '${_currentIndex + 1} / ${widget.files.length}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              )
            : null,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
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
          minScale: 0.8,
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