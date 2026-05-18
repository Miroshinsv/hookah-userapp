import 'package:flutter/material.dart';
import '../core/models/lounge.dart';

class LoungePhotoGallery extends StatefulWidget {
  final List<LoungePhoto> photos;

  const LoungePhotoGallery({super.key, required this.photos});

  @override
  State<LoungePhotoGallery> createState() => _LoungePhotoGalleryState();
}

class _LoungePhotoGalleryState extends State<LoungePhotoGallery> {
  int _current = 0;
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (ctx, i) => Image.network(
              photos[i].url,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade900,
                child: const Icon(Icons.broken_image,
                    color: Colors.white38, size: 48),
              ),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
            ),
          ),
          if (photos.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  photos.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _current ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _current
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
