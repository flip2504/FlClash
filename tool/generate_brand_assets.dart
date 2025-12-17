import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const _defaultBrandId = 'flclash';

Future<void> main(List<String> args) async {
  final parser =
      ArgParser()
        ..addOption(
          'brand',
          abbr: 'b',
          help: 'Brand id (maps to .github/<brand>.json).',
        )
        ..addOption(
          'brand-file',
          help: 'Brand config json path. Defaults to .github/<brand>.json',
        )
        ..addOption(
          'output-root',
          help: 'Output directory. Defaults to brands/<brandId>/',
        )
        ..addFlag(
          'force',
          help: 'Regenerate and overwrite existing files.',
          defaultsTo: true,
        )
        ..addOption(
          'icon',
          help:
              'Override icon source (url or local path). If set, ignores assets.icon in json.',
        );

  final result = parser.parse(args);
  final brandIdRaw = (result['brand'] as String?)?.trim();
  final brandId = brandIdRaw?.isNotEmpty == true ? brandIdRaw! : _defaultBrandId;
  final brandFilePath =
      (result['brand-file'] as String?)?.trim().isNotEmpty == true
          ? (result['brand-file'] as String).trim()
          : p.join('.github', '$brandId.json');
  final outputRoot =
      (result['output-root'] as String?)?.trim().isNotEmpty == true
          ? (result['output-root'] as String).trim()
          : p.join('brands', _safePathSegment(brandId));
  final force = result['force'] == true;

  final jsonFile = File(brandFilePath);
  if (!jsonFile.existsSync()) {
    if (brandId == _defaultBrandId) {
      stdout.writeln('No brand file ($brandFilePath); skip brand assets.');
      return;
    }
    stderr.writeln('Brand config not found: $brandFilePath');
    exitCode = 2;
    return;
  }

  final jsonMap = json.decode(await jsonFile.readAsString());
  if (jsonMap is! Map<String, dynamic>) {
    stderr.writeln('Invalid brand config json: $brandFilePath');
    exitCode = 2;
    return;
  }

  final overrideIcon = (result['icon'] as String?)?.trim();
  final iconSource =
      overrideIcon?.isNotEmpty == true ? overrideIcon! : _readAssetsIcon(jsonMap);
  if (iconSource == null || iconSource.trim().isEmpty) {
    stdout.writeln('No assets.icon in $brandFilePath; skip asset generation.');
    return;
  }

  stdout.writeln('Generating brand assets for "$brandId" from "$iconSource"...');

  final bytes = await _loadSourceBytes(iconSource);
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln('Failed to decode image: $iconSource');
    exitCode = 2;
    return;
  }

  final square = _makeSquare(decoded);
  await _generateTray(square, p.join(outputRoot, 'tray'), force: force);
  await _generateWindowsIcon(square, p.join(outputRoot, 'windows', 'app_icon.ico'), force: force);
  await _generateMacosIconset(square, p.join(outputRoot, 'macos', 'AppIcon.appiconset'), force: force);
  await _generateAndroidRes(square, p.join(outputRoot, 'android', 'res'), force: force);

  stdout.writeln('Brand assets generated under "$outputRoot".');
}

String? _readAssetsIcon(Map<String, dynamic> jsonMap) {
  final assets = jsonMap['assets'];
  if (assets is! Map) return null;
  const keys = [
    'icon',
    'icon_url',
    'iconUrl',
    'icon_png',
    'iconPng',
    'source_image',
    'sourceImage',
  ];
  for (final key in keys) {
    final v = assets[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

Future<Uint8List> _loadSourceBytes(String source) async {
  final trimmed = source.trim();
  if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
    final uri = Uri.parse(trimmed);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'flclash-brand-assets/1.0');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw 'HTTP ${response.statusCode}';
      }
      final data = await response.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      );
      return Uint8List.fromList(data);
    } finally {
      client.close(force: true);
    }
  }

  final file = File(p.isAbsolute(trimmed) ? trimmed : p.join(Directory.current.path, trimmed));
  return file.readAsBytes();
}

String _safePathSegment(String input) {
  final safe = input.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return safe.isEmpty ? _defaultBrandId : safe;
}

img.Image _makeSquare(img.Image src) {
  final size = max(src.width, src.height);
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  final x = ((size - src.width) / 2).round();
  final y = ((size - src.height) / 2).round();
  img.compositeImage(canvas, src, dstX: x, dstY: y);
  return canvas;
}

Future<void> _generateTray(img.Image square, String outDir, {required bool force}) async {
  final dir = Directory(outDir);
  await dir.create(recursive: true);

  final png = img.copyResize(
    square,
    width: 108,
    height: 108,
    interpolation: img.Interpolation.cubic,
  );

  for (final idx in [1, 2, 3]) {
    final pngPath = p.join(outDir, 'status_$idx.png');
    final icoPath = p.join(outDir, 'status_$idx.ico');
    await _writeIfNeeded(pngPath, img.encodePng(png), force: force);
    await _writeIfNeeded(icoPath, _encodeIco(square), force: force);
  }
}

Future<void> _generateWindowsIcon(
  img.Image square,
  String outFile, {
  required bool force,
}) async {
  final file = File(outFile);
  await file.parent.create(recursive: true);
  await _writeIfNeeded(outFile, _encodeIco(square), force: force);
}

Future<void> _generateMacosIconset(
  img.Image square,
  String outDir, {
  required bool force,
}) async {
  final dir = Directory(outDir);
  await dir.create(recursive: true);

  const contentJson =
      '{\n'
      '  "images" : [\n'
      '    {\n'
      '      "size" : "16x16",\n'
      '      "idiom" : "mac",\n'
      '      "filename" : "app_icon_16.png",\n'
      '      "scale" : "1x"\n'
      '    },\n'
      '    {\n'
      '      "size" : "16x16",\n'
      '      "idiom" : "mac",\n'
      '      "filename" : "app_icon_32.png",\n'
      '      "scale" : "2x"\n'
      '    },\n'
      '    {\n'
      '      "size" : "32x32",\n'
      '      "idiom" : "mac",\n'
      '      "filename" : "app_icon_32.png",\n'
      '      "scale" : "1x"\n'
      '    },\n'
      '    {\n'
      '      "size" : "32x32",\n'
      '      "idiom" : "mac",\n'
      '      "filename" : "app_icon_64.png",\n'
      '      "scale" : "2x"\n'
      '    },\n'
      '    {\n'
      '      "size" : "128x128",\n'
      '      "idiom" : "mac",\n'
      '      "filename" : "app_icon_128.png",\n'
      '      "scale" : "1x"\n'
      '    },\n'
      '    {\n'
      '      "size" : "128x128",\n'
      '      "idiom" : "mac",\n'
      '      "filename" : "app_icon_256.png",\n'
      '      "scale" : "2x"\n'
      '    },\n'
      '    {\n'
      '      "size" : "256x256",\n'
      '      "idiom" : "mac",\n'
      '      "filename" : "app_icon_256.png",\n'
      '      "scale" : "1x"\n'
      '    },\n'
      '    {\n'
      '      "size" : "256x256",\n'
      '      "idiom" : "mac",\n'
      '      "filename" : "app_icon_512.png",\n'
      '      "scale" : "2x"\n'
      '    },\n'
      '    {\n'
      '      "size" : "512x512",\n'
      '      "idiom" : "mac",\n'
      '      "filename" : "app_icon_512.png",\n'
      '      "scale" : "1x"\n'
      '    },\n'
      '    {\n'
      '      "size" : "512x512",\n'
      '      "idiom" : "mac",\n'
      '      "filename" : "app_icon_1024.png",\n'
      '      "scale" : "2x"\n'
      '    }\n'
      '  ],\n'
      '  "info" : {\n'
      '    "version" : 1,\n'
      '    "author" : "xcode"\n'
      '  }\n'
      '}\n';

  await _writeIfNeeded(p.join(outDir, 'Contents.json'), utf8.encode(contentJson), force: force);

  final sizes = <int>[16, 32, 64, 128, 256, 512, 1024];
  for (final size in sizes) {
    final outPath = p.join(outDir, 'app_icon_$size.png');
    final resized = img.copyResize(
      square,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    await _writeIfNeeded(outPath, img.encodePng(resized), force: force);
  }
}

Future<void> _generateAndroidRes(
  img.Image square,
  String outDir, {
  required bool force,
}) async {
  final dir = Directory(outDir);
  await dir.create(recursive: true);

  final densities = <String, int>{
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in densities.entries) {
    final densityDir = Directory(p.join(outDir, entry.key));
    await densityDir.create(recursive: true);
    final size = entry.value;
    final resized = img.copyResize(
      square,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );

    await _writeIfNeeded(p.join(densityDir.path, 'ic_launcher.png'), img.encodePng(resized), force: force);
    await _writeIfNeeded(
      p.join(densityDir.path, 'ic_launcher_round.png'),
      img.encodePng(resized),
      force: force,
    );
    await _writeIfNeeded(
      p.join(densityDir.path, 'ic_launcher_foreground.png'),
      img.encodePng(resized),
      force: force,
    );
  }

  final drawableDir = Directory(p.join(outDir, 'drawable'));
  await drawableDir.create(recursive: true);

  const launcherForegroundXml =
      '<?xml version="1.0" encoding="utf-8"?>\n'
      '<bitmap xmlns:android="http://schemas.android.com/apk/res/android"\n'
      '    android:src="@mipmap/ic_launcher_foreground"\n'
      '    android:gravity="center" />\n';
  await _writeIfNeeded(
    p.join(drawableDir.path, 'ic_launcher_foreground.xml'),
    utf8.encode(launcherForegroundXml),
    force: force,
  );

  final icPng = img.copyResize(
    square,
    width: 240,
    height: 240,
    interpolation: img.Interpolation.cubic,
  );
  await _writeIfNeeded(p.join(drawableDir.path, 'ic.png'), img.encodePng(icPng), force: force);
  await _writeIfNeeded(
    p.join(drawableDir.path, 'ic_service.png'),
    img.encodePng(icPng),
    force: force,
  );

  final bannerDir = Directory(p.join(outDir, 'mipmap-xhdpi'));
  await bannerDir.create(recursive: true);

  final banner = img.Image(width: 320, height: 180, numChannels: 4);
  img.fill(banner, color: img.ColorRgba8(250, 250, 250, 255));
  final bannerIconSize = 160;
  final bannerIcon = img.copyResize(
    square,
    width: bannerIconSize,
    height: bannerIconSize,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    banner,
    bannerIcon,
    dstX: ((banner.width - bannerIcon.width) / 2).round(),
    dstY: ((banner.height - bannerIcon.height) / 2).round(),
  );
  await _writeIfNeeded(
    p.join(bannerDir.path, 'ic_banner.png'),
    img.encodePng(banner),
    force: force,
  );
}

Uint8List _encodeIco(img.Image square) {
  final sizes = <int>[256, 128, 64, 48, 32, 16];
  final frames = sizes
      .map(
        (size) => img.copyResize(
          square,
          width: size,
          height: size,
          interpolation: img.Interpolation.cubic,
        ),
      )
      .toList();
  return img.IcoEncoder().encodeImages(frames);
}

Future<void> _writeIfNeeded(String path, List<int> bytes, {required bool force}) async {
  final file = File(path);
  if (!force && await file.exists()) {
    return;
  }
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

