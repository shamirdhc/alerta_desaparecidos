import 'package:flutter/material.dart';
import 'platform_image_stub.dart'
    if (dart.library.html) 'platform_image_web.dart'
    if (dart.library.io) 'platform_image_io.dart';

Widget buildPlatformCachedImage({
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
  return buildWebOrNativeImage(
    imageUrl: imageUrl,
    fallbackImageUrl: fallbackImageUrl,
    width: width,
    height: height,
    fit: fit,
    borderRadius: borderRadius,
    memCacheWidth: memCacheWidth,
    memCacheHeight: memCacheHeight,
    placeholder: placeholder,
    errorWidget: errorWidget,
  );
}

