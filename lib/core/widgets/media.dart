import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// Full URL for a stored photo path ("/uploads/..." from our API, or an https link).
String photoUrl(dynamic p) {
  final s = '${p ?? ''}';
  if (s.isEmpty) return '';
  return s.startsWith('http') ? s : '${AgriApi.host}$s';
}

/// Small copy made by the server for every upload: /uploads/x/photo.jpg -> /uploads/x/photo_t.jpg
String thumbUrl(String url) =>
    url.contains('/uploads/') && !url.contains('/payments/') ? url.replaceFirst(RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false), '_t.jpg') : url;

/// First photo of an item (listing, machine, warehouse, crop) or '' if none.
String firstPhoto(Map item) {
  final l = item['photos'];
  return l is List && l.isNotEmpty ? photoUrl(l.first) : '';
}

/// Built-in picture shown when an item has no photo yet.
String fallbackAsset(String kind) {
  switch (kind) {
    case 'machine':
      return 'assets/img/hero_tractor.png';
    case 'warehouse':
      return 'assets/img/hero_warehouse.png';
    case 'crop':
      return 'assets/img/hero_field.png';
    default:
      return 'assets/img/hero_market.png';
  }
}

/// Pick an image (gallery / camera) and upload it. Returns the stored path, or null if cancelled.
Future<String?> pickAndUpload(BuildContext context, String folder, {ImageSource? source}) async {
  ImageSource? src = source;
  src ??= await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.photo_library_outlined, color: C.green),
          title: Text(tr('Choose from gallery')),
          onTap: () => Navigator.pop(c, ImageSource.gallery),
        ),
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined, color: C.green),
          title: Text(tr('Take a photo')),
          onTap: () => Navigator.pop(c, ImageSource.camera),
        ),
      ]),
    ),
  );
  if (src == null) return null;
  final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 78);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  final n = x.name.toLowerCase();
  final mime = n.endsWith('.png') ? 'image/png' : (n.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
  final r = await AgriApi.post('/uploads', {
    'folder': folder,
    'image': 'data:$mime;base64,${base64Encode(bytes)}',
  });
  return '${(r as Map)['url']}';
}

/// Rounded photo with a built-in fallback picture while loading / when missing.
class NetPhoto extends StatelessWidget {
  final String url;
  final String kind;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  /// Load the small 400px copy first (lists / cards). Falls back to the full photo.
  final bool thumb;
  const NetPhoto({
    super.key,
    required this.url,
    this.thumb = false,
    this.kind = 'listing',
    this.width,
    this.height,
    this.radius = 12,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final fb = Image.asset(fallbackAsset(kind), width: width, height: height, fit: BoxFit.cover);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? fb
          : CachedNetworkImage(
              imageUrl: thumb ? thumbUrl(url) : url,
              width: width,
              height: height,
              fit: fit,
              fadeInDuration: const Duration(milliseconds: 200),
              // old photos have no thumbnail yet: show the full one instead
              errorWidget: (_, _, _) => thumb && thumbUrl(url) != url
                  ? CachedNetworkImage(imageUrl: url, width: width, height: height, fit: fit, errorWidget: (_, _, _) => fb)
                  : fb,
              placeholder: (_, _) => Container(
                width: width,
                height: height,
                color: C.light,
                alignment: Alignment.center,
                child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: C.green)),
              ),
            ),
    );
  }
}

/// Swipeable photo gallery for detail pages (tap to zoom).
class PhotoGallery extends StatefulWidget {
  final List photos;
  final String kind;
  final double height;
  const PhotoGallery({super.key, required this.photos, this.kind = 'listing', this.height = 220});
  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  int _i = 0;

  void _zoom(String url) => showDialog(
        context: context,
        builder: (d) => Dialog(
          insetPadding: const EdgeInsets.all(10),
          backgroundColor: Colors.black,
          child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final urls = widget.photos.map(photoUrl).where((u) => u.isNotEmpty).toList();
    if (urls.isEmpty) {
      return NetPhoto(url: '', kind: widget.kind, height: widget.height, width: double.infinity, radius: 16);
    }
    return SizedBox(
      height: widget.height,
      child: Stack(children: [
        PageView.builder(
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _zoom(urls[i]),
            child: NetPhoto(url: urls[i], kind: widget.kind, height: widget.height, width: double.infinity, radius: 16),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                urls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _i ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _i ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Text('${_i + 1}/${urls.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ),
      ]),
    );
  }
}

/// Form field: up to [max] photos with add / remove. Uploads straight away and reports the stored paths.
class PhotoPickerField extends StatefulWidget {
  final List<String> photos;
  final String folder;
  final ValueChanged<List<String>> onChanged;
  final int max;
  final String label;
  const PhotoPickerField({
    super.key,
    required this.photos,
    required this.folder,
    required this.onChanged,
    this.max = 6,
    this.label = 'Photos',
  });
  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  late List<String> _p = List.of(widget.photos);
  bool _busy = false;

  @override
  void didUpdateWidget(covariant PhotoPickerField old) {
    super.didUpdateWidget(old);
    if (old.photos != widget.photos) _p = List.of(widget.photos);
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      final url = await pickAndUpload(context, widget.folder);
      if (url != null && mounted) {
        setState(() => _p.add(url));
        widget.onChanged(List.of(_p));
      }
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _remove(int i) {
    setState(() => _p.removeAt(i));
    widget.onChanged(List.of(_p));
  }

  @override
  Widget build(BuildContext context) {
    Widget tile(Widget child) => Container(
          width: 84,
          height: 84,
          margin: const EdgeInsets.only(right: 8, bottom: 8),
          child: child,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tr(widget.label), style: const TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${_p.length}/${widget.max}', style: const TextStyle(fontSize: 11, color: C.grey)),
        ]),
        const SizedBox(height: 6),
        Wrap(children: [
          for (var i = 0; i < _p.length; i++)
            tile(Stack(children: [
              Positioned.fill(child: NetPhoto(url: photoUrl(_p[i]), radius: 12)),
              if (i == 0)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(6)),
                    child: Text(tr('Cover'), style: const TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ),
              Positioned(
                right: 2,
                top: 2,
                child: InkWell(
                  onTap: () => _remove(i),
                  child: const CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ])),
          if (_p.length < widget.max)
            tile(InkWell(
              onTap: _busy ? null : _add,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: C.light,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.green.withValues(alpha: 0.4)),
                ),
                child: _busy
                    ? const Center(
                        child: SizedBox(
                            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: C.green)))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.add_a_photo_outlined, color: C.green),
                        const SizedBox(height: 4),
                        Text(tr('Add photo'), style: const TextStyle(fontSize: 10, color: C.green)),
                      ]),
              ),
            )),
        ]),
      ]),
    );
  }
}
