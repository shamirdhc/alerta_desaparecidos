// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

final Set<String> _registeredViews = {};

Widget buildWebOrNativeImage({
  required String imageUrl,
  String? fallbackImageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
  int memCacheWidth = 500,
  int? memCacheHeight = 650,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  // En Web, si la URL proviene del servidor policial PNP (sistemas.policia.gob.pe)
  // o de Firebase Storage, usamos el elemento <img> nativo del DOM.
  // Los elementos <img> nativos del navegador NO tienen bloqueo de CORS
  // y se benefician de la aceleración por hardware del motor del navegador.
  final isPoliceOrStorageUrl = imageUrl.contains('sistemas.policia.gob.pe') ||
      imageUrl.contains('policia.gob.pe') ||
      imageUrl.contains('firebasestorage.googleapis.com');

  if (isPoliceOrStorageUrl) {
    final viewType = 'pnp-img-${imageUrl.hashCode.abs()}';

    if (!_registeredViews.contains(viewType)) {
      _registeredViews.add(viewType);
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final img = html.ImageElement()
          ..src = imageUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = fit == BoxFit.contain ? 'contain' : 'cover'
          ..style.border = 'none'
          ..style.display = 'block';

        if (borderRadius != null) {
          img.style.borderRadius = '${borderRadius.topLeft.x}px';
        }

        if (fallbackImageUrl != null &&
            fallbackImageUrl.isNotEmpty &&
            fallbackImageUrl != imageUrl) {
          img.onError.listen((_) {
            img.src = fallbackImageUrl;
          });
        }

        return img;
      });
    }

    Widget htmlView = SizedBox(
      width: width,
      height: height,
      child: HtmlElementView(viewType: viewType),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius, child: htmlView);
    }
    return htmlView;
  }

  // Para otras URLs estándar en Web con soporte CORS:
  Widget img = CachedNetworkImage(
    imageUrl: imageUrl,
    width: width,
    height: height,
    fit: fit,
    memCacheWidth: memCacheWidth,
    memCacheHeight: memCacheHeight,
    placeholder: (context, url) => placeholder ?? const SizedBox.shrink(),
    errorWidget: (context, url, err) {
      if (fallbackImageUrl != null &&
          fallbackImageUrl.isNotEmpty &&
          fallbackImageUrl != imageUrl) {
        return buildWebOrNativeImage(
          imageUrl: fallbackImageUrl,
          width: width,
          height: height,
          fit: fit,
          borderRadius: borderRadius,
          placeholder: placeholder,
          errorWidget: errorWidget,
        );
      }
      return errorWidget ?? const SizedBox.shrink();
    },
  );

  if (borderRadius != null) {
    return ClipRRect(borderRadius: borderRadius, child: img);
  }
  return img;
}

