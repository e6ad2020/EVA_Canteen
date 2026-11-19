import 'dart:collection';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:material_ui/material_ui.dart';

/// Persistent disk + quantized memory image cache utilities for EVA Canteen.
///
/// - On Android/iOS/Desktop, network images are persisted on disk for 14 days
///   (up to 300 files) via [CacheManager] so switching tabs, categories, or
///   restarting the app never re-downloads product photos.
/// - On Flutter Web (including `--wasm`), images delegate cleanly to the
///   browser's native HTTP cache via `Image.network` with quantized `cacheWidth`.
/// - Decoded bitmaps are quantized into 3 width buckets (`160`, `480`, `960` px)
///   so identical product images across menu cards, combo thumbnails, checkout
///   sheets, and detail modals share RAM cache entries and use ~60x less memory
///   than full-resolution camera uploads.
class EvaImageCache {
  EvaImageCache._();

  static const String cacheKey = 'eva_canteen_media_v1';
  static const int maxDiskCacheWidth = 1200;

  static CacheManager? _diskManager;

  /// Returns true when running inside `flutter test` bindings where native
  /// `sqflite`/`path_provider` plugins are unavailable.
  static bool get _isWidgetTestBinding {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  /// Whether native disk caching should be used for the current runtime.
  static bool get supportsDiskCache => !kIsWeb && !_isWidgetTestBinding;

  /// Shared persistent [CacheManager] on native platforms (`null` on Web/tests).
  static BaseCacheManager? get diskCacheManager {
    if (!supportsDiskCache) return null;
    return _diskManager ??= CacheManager(
      Config(
        cacheKey,
        stalePeriod: const Duration(days: 14),
        maxNrOfCacheObjects: 300,
      ),
    );
  }

  /// Configures Flutter's in-memory decoded bitmap cache for smooth tab switches.
  static void configureMemoryCache() {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = 300;
    cache.maximumSizeBytes = 150 << 20; // 150 MiB
  }

  /// Quantizes a target physical pixel width into a small set of buckets so
  /// slightly different layout widths reuse the exact same RAM `ResizeImage`.
  static int quantizeCacheWidth(double logicalWidth, double devicePixelRatio) {
    if (!logicalWidth.isFinite || logicalWidth <= 0) {
      return 480;
    }
    final physical = (logicalWidth * devicePixelRatio).round();
    if (physical <= 160) return 160;
    if (physical <= 480) return 480;
    return 960;
  }

  // Bounded LRU cache for decoded `data:image/...;base64,...` bytes so data URIs
  // work reliably on Android/iOS as well as Web without repeated base64 decoding.
  static final LinkedHashMap<String, Uint8List> _dataUriBytes =
      LinkedHashMap<String, Uint8List>();
  static const int _maxDataUriEntries = 32;

  static Uint8List? decodeDataUri(String dataUri) {
    final cached = _dataUriBytes.remove(dataUri);
    if (cached != null) {
      _dataUriBytes[dataUri] = cached;
      return cached;
    }
    final commaIdx = dataUri.indexOf(',');
    if (commaIdx <= 0 || commaIdx >= dataUri.length - 1) return null;
    try {
      final bytes = base64Decode(
        dataUri.substring(commaIdx + 1).replaceAll(RegExp(r'\s+'), ''),
      );
      _dataUriBytes[dataUri] = bytes;
      if (_dataUriBytes.length > _maxDataUriEntries) {
        _dataUriBytes.remove(_dataUriBytes.keys.first);
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Builds the exact [ImageProvider] (including quantized [ResizeImage]) that
  /// [EvaCachedImage] resolves for [url] at [logicalWidth] and
  /// [devicePixelRatio], ensuring pre-warmed entries hit Flutter's [ImageCache].
  static ImageProvider? resolveImageProvider({
    required String url,
    required double logicalWidth,
    required double devicePixelRatio,
    BaseCacheManager? cacheManager,
  }) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final memWidth = quantizeCacheWidth(logicalWidth, devicePixelRatio);
    if (trimmed.startsWith('data:')) {
      final bytes = decodeDataUri(trimmed);
      if (bytes == null) return null;
      return ResizeImage.resizeIfNeeded(memWidth, null, MemoryImage(bytes));
    }

    final effectiveManager = cacheManager ?? diskCacheManager;
    final ImageProvider baseProvider = effectiveManager == null
        ? NetworkImage(trimmed)
        : CachedNetworkImageProvider(
            trimmed,
            cacheManager: effectiveManager,
            maxWidth: maxDiskCacheWidth,
          );
    return ResizeImage.resizeIfNeeded(memWidth, null, baseProvider);
  }

  /// Non-blockingly pre-warms [url] into Flutter's [ImageCache] (and disk cache
  /// on native platforms) using the exact quantized width bucket that
  /// [EvaCachedImage] will request. Skipped in headless `flutter test` bindings
  /// to avoid live network I/O.
  static Future<void> precacheUrl(
    BuildContext context, {
    required String url,
    required double logicalWidth,
    BaseCacheManager? cacheManager,
  }) async {
    if (_isWidgetTestBinding) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final provider = resolveImageProvider(
      url: url,
      logicalWidth: logicalWidth,
      devicePixelRatio: dpr,
      cacheManager: cacheManager,
    );
    if (provider == null) return;
    try {
      await precacheImage(provider, context, onError: (_, _) {});
    } catch (_) {
      // Ignore offline/network pre-warm errors cleanly.
    }
  }
}

/// Drop-in cached network/data-URI image widget with quantized RAM sizing,
/// persistent disk caching on mobile/desktop, and zero-flash reuse across tabs.
class EvaCachedImage extends StatelessWidget {
  const EvaCachedImage({
    super.key,
    required this.url,
    required this.placeholderBuilder,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.medium,
    this.cacheManager,
  });

  final String url;
  final WidgetBuilder placeholderBuilder;
  final WidgetBuilder errorBuilder;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final BaseCacheManager? cacheManager;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return errorBuilder(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final memWidth = EvaImageCache.quantizeCacheWidth(
          constraints.maxWidth,
          dpr,
        );

        if (trimmed.startsWith('data:')) {
          final bytes = EvaImageCache.decodeDataUri(trimmed);
          if (bytes == null) return errorBuilder(context);
          return Image.memory(
            bytes,
            fit: fit,
            cacheWidth: memWidth,
            gaplessPlayback: true,
            filterQuality: filterQuality,
            errorBuilder: (ctx, _, _) => errorBuilder(ctx),
          );
        }

        final effectiveManager = cacheManager ?? EvaImageCache.diskCacheManager;
        if (effectiveManager == null) {
          return Image.network(
            trimmed,
            fit: fit,
            cacheWidth: memWidth,
            gaplessPlayback: true,
            filterQuality: filterQuality,
            errorBuilder: (ctx, _, _) => errorBuilder(ctx),
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return placeholderBuilder(ctx);
            },
          );
        }

        return CachedNetworkImage(
          imageUrl: trimmed,
          cacheManager: effectiveManager,
          fit: fit,
          filterQuality: filterQuality,
          memCacheWidth: memWidth,
          maxWidthDiskCache: EvaImageCache.maxDiskCacheWidth,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          useOldImageOnUrlChange: true,
          placeholder: (ctx, _) => placeholderBuilder(ctx),
          errorWidget: (ctx, _, _) => errorBuilder(ctx),
        );
      },
    );
  }
}
