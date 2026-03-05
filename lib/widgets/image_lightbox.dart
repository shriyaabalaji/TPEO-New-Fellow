import 'package:flutter/material.dart';

/// Fraction of screen width/height for the lightbox (3/5).
const double _kLightboxSizeFraction = 0.6;

/// Border radius for the lightbox container.
const double _kLightboxRadius = 24;

/// Shows a single image in a smaller rounded popup (~3/5 of screen). Tap outside to close.
void showImageLightbox(BuildContext context, Widget image) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kLightboxRadius),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(ctx).width * _kLightboxSizeFraction,
                  maxHeight: MediaQuery.sizeOf(ctx).height * _kLightboxSizeFraction,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(_kLightboxRadius),
                ),
                child: InteractiveViewer(
                  child: image,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Shows multiple images in a gallery with arrows and swipe. Tap outside to close.
void showGalleryLightbox(
  BuildContext context, {
  required List<Widget> images,
  int initialIndex = 0,
}) {
  if (images.isEmpty) return;
  if (images.length == 1) {
    showImageLightbox(context, images.single);
    return;
  }
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (ctx) => _GalleryLightboxContent(
      images: images,
      initialIndex: initialIndex,
      onClose: () => Navigator.pop(ctx),
    ),
  );
}

class _GalleryLightboxContent extends StatefulWidget {
  const _GalleryLightboxContent({
    required this.images,
    required this.initialIndex,
    required this.onClose,
  });

  final List<Widget> images;
  final int initialIndex;
  final VoidCallback onClose;

  @override
  State<_GalleryLightboxContent> createState() => _GalleryLightboxContentState();
}

class _GalleryLightboxContentState extends State<_GalleryLightboxContent> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kLightboxRadius),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * _kLightboxSizeFraction,
                  maxHeight: MediaQuery.sizeOf(context).height * _kLightboxSizeFraction,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(_kLightboxRadius),
                ),
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: widget.images.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemBuilder: (_, i) => InteractiveViewer(
                        child: widget.images[i],
                      ),
                    ),
                    if (_currentIndex > 0)
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.chevron_left, color: Colors.white, size: 32),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_currentIndex < widget.images.length - 1)
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.chevron_right, color: Colors.white, size: 32),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
