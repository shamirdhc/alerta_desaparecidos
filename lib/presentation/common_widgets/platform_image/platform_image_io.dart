import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        return CachedNetworkImage(
          imageUrl: fallbackImageUrl,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          placeholder: (context, url) => placeholder ?? const SizedBox.shrink(),
          errorWidget: (context, url, e) => errorWidget ?? const SizedBox.shrink(),
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

