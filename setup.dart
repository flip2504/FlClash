// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';

const defaultBrandId = 'flclash';

class BrandConfig {
  final String id;
  final String appName;
  final String repository;
  final List<String> urlSchemes;

  final String? androidApplicationId;
  final String? macosBundleId;

  final String windowsAppId;
  final String windowsBinaryName;
  final String windowsExecutableName;
  final String windowsCoreBinaryName;
  final String windowsCoreExecutableName;
  final String windowsHelperServiceName;
  final int windowsHelperPort;

  final int defaultMixedPort;
  final int externalControllerPort;
  final int dnsListenPort;

  final String? assetsIcon;
  final String? trayAssetDir;
  final String? windowsAppIconIco;
  final String? macosAppIconsetDir;
  final String? androidResDir;

  const BrandConfig({
    required this.id,
    required this.appName,
    required this.repository,
    required this.urlSchemes,
    required this.androidApplicationId,
    required this.macosBundleId,
    required this.windowsAppId,
    required this.windowsBinaryName,
    required this.windowsExecutableName,
    required this.windowsCoreBinaryName,
    required this.windowsCoreExecutableName,
    required this.windowsHelperServiceName,
    required this.windowsHelperPort,
    required this.defaultMixedPort,
    required this.externalControllerPort,
    required this.dnsListenPort,
    required this.assetsIcon,
    required this.trayAssetDir,
    required this.windowsAppIconIco,
    required this.macosAppIconsetDir,
    required this.androidResDir,
  });

  static BrandConfig flclash() {
    return const BrandConfig(
      id: defaultBrandId,
      appName: 'FlClash',
      repository: 'chen08209/FlClash',
      urlSchemes: ['clash', 'clashmeta', 'flclash'],
      androidApplicationId: 'com.follow.clash',
      macosBundleId: 'com.follow.clash',
      windowsAppId: '728B3532-C74B-4870-9068-BE70FE12A3E6',
      windowsBinaryName: 'FlClash',
      windowsExecutableName: 'FlClash.exe',
      windowsCoreBinaryName: 'FlClashCore',
      windowsCoreExecutableName: 'FlClashCore.exe',
      windowsHelperServiceName: 'FlClashHelperService',
      windowsHelperPort: 47890,
      defaultMixedPort: 7890,
      externalControllerPort: 9090,
      dnsListenPort: 1053,
      assetsIcon: null,
      trayAssetDir: null,
      windowsAppIconIco: null,
      macosAppIconsetDir: null,
      androidResDir: null,
    );
  }

  static Future<BrandConfig> load({
    required String brandId,
    String? brandFilePath,
  }) async {
    final normalizedBrandId = brandId.trim().isEmpty
        ? defaultBrandId
        : brandId.trim();
    final filePath =
        brandFilePath ??
        join(Directory.current.path, '.github', '$normalizedBrandId.json');
    final file = File(filePath);
    if (!file.existsSync()) {
      if (normalizedBrandId == defaultBrandId ||
          normalizedBrandId == 'default') {
        return flclash();
      }
      throw 'Brand config not found: $filePath';
    }
    final raw = json.decode(await file.readAsString());
    if (raw is! Map<String, dynamic>) {
      throw 'Invalid brand config json: $filePath';
    }
    return fromJson(raw, fallbackId: normalizedBrandId);
  }

  static BrandConfig fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
  }) {
    String readString(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    Map<String, dynamic> readMap(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is Map<String, dynamic>) return v;
      }
      return const {};
    }

    int? readInt(Map<String, dynamic> map, List<String> keys) {
      for (final k in keys) {
        final v = map[k];
        if (v is int) return v;
        if (v is String) return int.tryParse(v);
      }
      return null;
    }

    String? readOptionalString(Map<String, dynamic> map, List<String> keys) {
      for (final k in keys) {
        final v = map[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    final id = readString(['id', 'brand_id', 'brandId']).ifEmpty(fallbackId);

    final appName = readString([
      'app_name',
      'appName',
      'name',
    ]).ifEmpty('FlClash');
    final repository = readString(['repository']).ifEmpty('chen08209/FlClash');

    final urlSchemesRaw = json['url_schemes'] ?? json['urlSchemes'];
    final urlSchemes = <String>[
      if (urlSchemesRaw is List)
        ...urlSchemesRaw.map((e) => e.toString()).where((e) => e.isNotEmpty),
    ];

    final android = readMap(['android']);
    final macos = readMap(['macos']);
    final windows = readMap(['windows']);
    final ports = readMap(['ports']);
    final assets = readMap(['assets']);

    final androidApplicationId = readOptionalString(android, [
      'application_id',
      'applicationId',
      'package_name',
      'packageName',
    ]);

    final macosBundleId = readOptionalString(macos, [
      'bundle_id',
      'bundleId',
      'app_id',
      'appId',
    ]);

    final windowsAppId =
        readOptionalString(windows, ['app_id', 'appId']) ??
        _uuidFromName('flclash:$id');

    final windowsBinaryNameInput =
        readOptionalString(windows, ['binary_name', 'binaryName']) ??
        (id == defaultBrandId ? appName : '$appName-$id');
    final windowsBinaryName = _sanitizeWindowsBinaryName(
      windowsBinaryNameInput,
      fallback: 'FlClash',
    );
    final windowsExecutableName =
        readOptionalString(windows, ['executable_name', 'executableName']) ??
        '$windowsBinaryName.exe';

    final windowsCoreBinaryName = _sanitizeWindowsBinaryName(
      readOptionalString(windows, ['core_binary_name', 'coreBinaryName']) ??
          '${windowsBinaryName}Core',
      fallback: 'FlClashCore',
    );
    final windowsCoreExecutableName =
        readOptionalString(windows, [
          'core_executable_name',
          'coreExecutableName',
        ]) ??
        '$windowsCoreBinaryName.exe';

    final windowsHelperServiceName = _sanitizeWindowsServiceName(
      readOptionalString(windows, [
            'helper_service_name',
            'helperServiceName',
          ]) ??
          '${windowsBinaryName}HelperService',
      fallback: 'FlClashHelperService',
    );

    final windowsHelperPort =
        readInt(windows, ['helper_port', 'helperPort']) ??
        readInt(ports, ['helper_port', 'helperPort']) ??
        _hashToPort(id, base: 47890, range: 1000);

    final defaultMixedPort =
        readInt(ports, ['mixed_port', 'mixedPort']) ??
        _hashToPort(id, base: 7890, range: 1000);
    final externalControllerPort =
        readInt(ports, [
          'external_controller_port',
          'externalControllerPort',
        ]) ??
        _hashToPort(id, base: 9090, range: 1000);
    final dnsListenPort =
        readInt(ports, [
          'dns_listen_port',
          'dnsListenPort',
          'dns_port',
          'dnsPort',
        ]) ??
        _hashToPort(id, base: 1053, range: 1000);

    final trayAssetDir = readOptionalString(assets, [
      'tray_asset_dir',
      'trayAssetDir',
    ]);
    final windowsAppIconIco = readOptionalString(assets, [
      'windows_app_icon_ico',
      'windowsAppIconIco',
    ]);
    final macosAppIconsetDir = readOptionalString(assets, [
      'macos_app_iconset_dir',
      'macosAppIconsetDir',
    ]);
    final androidResDir = readOptionalString(assets, [
      'android_res_dir',
      'androidResDir',
    ]);
    final assetsIcon = readOptionalString(assets, [
      'icon',
      'icon_url',
      'iconUrl',
      'icon_png',
      'iconPng',
      'source_image',
      'sourceImage',
    ]);

    final safeBrandPathSegment =
        id.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_').ifEmpty(defaultBrandId);
    final inferredAssetRoot =
        assetsIcon == null ? null : join('brands', safeBrandPathSegment);
    final inferredTrayAssetDir =
        inferredAssetRoot == null ? null : join(inferredAssetRoot, 'tray');
    final inferredWindowsAppIconIco =
        inferredAssetRoot == null
            ? null
            : join(inferredAssetRoot, 'windows', 'app_icon.ico');
    final inferredMacosAppIconsetDir =
        inferredAssetRoot == null
            ? null
            : join(inferredAssetRoot, 'macos', 'AppIcon.appiconset');
    final inferredAndroidResDir =
        inferredAssetRoot == null
            ? null
            : join(inferredAssetRoot, 'android', 'res');

    return BrandConfig(
      id: id,
      appName: appName,
      repository: repository,
      urlSchemes: urlSchemes.isEmpty
          ? (id == defaultBrandId
                ? ['clash', 'clashmeta', 'flclash']
                : [_safeUrlScheme(id)])
          : urlSchemes,
      androidApplicationId:
          androidApplicationId ??
          (id == defaultBrandId
              ? 'com.follow.clash'
              : _defaultAndroidApplicationId(id)),
      macosBundleId:
          macosBundleId ??
          (id == defaultBrandId
              ? 'com.follow.clash'
              : _defaultMacosBundleId(id)),
      windowsAppId: windowsAppId,
      windowsBinaryName: windowsBinaryName,
      windowsExecutableName: windowsExecutableName,
      windowsCoreBinaryName: windowsCoreBinaryName,
      windowsCoreExecutableName: windowsCoreExecutableName,
      windowsHelperServiceName: windowsHelperServiceName,
      windowsHelperPort: windowsHelperPort,
      defaultMixedPort: defaultMixedPort,
      externalControllerPort: externalControllerPort,
      dnsListenPort: dnsListenPort,
      assetsIcon: assetsIcon,
      trayAssetDir: trayAssetDir ?? inferredTrayAssetDir,
      windowsAppIconIco: windowsAppIconIco ?? inferredWindowsAppIconIco,
      macosAppIconsetDir: macosAppIconsetDir ?? inferredMacosAppIconsetDir,
      androidResDir: androidResDir ?? inferredAndroidResDir,
    );
  }

  Map<String, String> get dartDefines => {
    'BRAND_ID': id,
    'APP_NAME': appName,
    'REPOSITORY': repository,
    'PROTOCOL_SCHEMES': urlSchemes.join(','),
    'DEFAULT_MIXED_PORT': defaultMixedPort.toString(),
    'EXTERNAL_CONTROLLER_PORT': externalControllerPort.toString(),
    'DNS_LISTEN_PORT': dnsListenPort.toString(),
    'APP_HELPER_SERVICE': windowsHelperServiceName,
    'HELPER_PORT': windowsHelperPort.toString(),
    'CORE_EXECUTABLE_NAME_WINDOWS': windowsCoreBinaryName,
  };
}

extension _StringExt on String {
  String ifEmpty(String value) => trim().isEmpty ? value : this;
}

String _sanitizeWindowsBinaryName(String input, {required String fallback}) {
  final sanitized = input
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return sanitized.isEmpty ? fallback : sanitized;
}

String _sanitizeWindowsServiceName(String input, {required String fallback}) {
  final sanitized = input
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return sanitized.isEmpty ? fallback : sanitized;
}

String _safeAndroidPackageSegment(String input, {required String fallback}) {
  final sanitized = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (sanitized.isEmpty) return fallback;
  if (!RegExp(r'^[a-z]').hasMatch(sanitized)) {
    return '${fallback}_$sanitized';
  }
  return sanitized;
}

String _defaultAndroidApplicationId(String brandId) {
  final segment = _safeAndroidPackageSegment(brandId, fallback: 'app');
  return 'com.flclash.$segment';
}

String _safeBundleIdSegment(String input, {required String fallback}) {
  final sanitized = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (sanitized.isEmpty) return fallback;
  if (!RegExp(r'^[a-z]').hasMatch(sanitized)) {
    return '$fallback-$sanitized';
  }
  return sanitized;
}

String _defaultMacosBundleId(String brandId) {
  final segment = _safeBundleIdSegment(brandId, fallback: 'app');
  return 'com.flclash.$segment';
}

String _safeUrlScheme(String brandId) {
  final slug = brandId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9+.-]+'), '-');
  return 'flclash-$slug'.replaceAll(RegExp(r'-+'), '-');
}

int _hashToPort(String brandId, {required int base, required int range}) {
  final digest = sha1.convert(utf8.encode('flclash:$brandId'));
  final bytes = digest.bytes;
  final value = (bytes[0] << 8) + bytes[1];
  final offset = value % range;
  return base + offset;
}

String _uuidFromName(String name) {
  final bytes = sha1.convert(utf8.encode(name)).bytes.toList();
  // UUID v5 (SHA-1) style bits: version=5, variant=RFC4122
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
  return [
    for (final i in [0, 1, 2, 3]) hex(i),
    '-',
    for (final i in [4, 5]) hex(i),
    '-',
    for (final i in [6, 7]) hex(i),
    '-',
    for (final i in [8, 9]) hex(i),
    '-',
    for (final i in [10, 11, 12, 13, 14, 15]) hex(i),
  ].join();
}

enum Target { windows, linux, android, macos }

extension TargetExt on Target {
  String get os {
    if (this == Target.macos) {
      return 'darwin';
    }
    return name;
  }

  bool get same {
    if (this == Target.android) {
      return true;
    }
    if (Platform.isWindows && this == Target.windows) {
      return true;
    }
    if (Platform.isLinux && this == Target.linux) {
      return true;
    }
    if (Platform.isMacOS && this == Target.macos) {
      return true;
    }
    return false;
  }

  String get dynamicLibExtensionName {
    final String extensionName;
    switch (this) {
      case Target.android || Target.linux:
        extensionName = '.so';
        break;
      case Target.windows:
        extensionName = '.dll';
        break;
      case Target.macos:
        extensionName = '.dylib';
        break;
    }
    return extensionName;
  }

  String get executableExtensionName {
    final String extensionName;
    switch (this) {
      case Target.windows:
        extensionName = '.exe';
        break;
      default:
        extensionName = '';
        break;
    }
    return extensionName;
  }
}

enum Mode { core, lib }

enum Arch { amd64, arm64, arm }

class BuildItem {
  Target target;
  Arch? arch;
  String? archName;

  BuildItem({required this.target, this.arch, this.archName});

  @override
  String toString() {
    return 'BuildLibItem{target: $target, arch: $arch, archName: $archName}';
  }
}

class Build {
  static List<BuildItem> get buildItems => [
    BuildItem(target: Target.macos, arch: Arch.arm64),
    BuildItem(target: Target.macos, arch: Arch.amd64),
    BuildItem(target: Target.linux, arch: Arch.arm64),
    BuildItem(target: Target.linux, arch: Arch.amd64),
    BuildItem(target: Target.windows, arch: Arch.amd64),
    BuildItem(target: Target.windows, arch: Arch.arm64),
    BuildItem(target: Target.android, arch: Arch.arm, archName: 'armeabi-v7a'),
    BuildItem(target: Target.android, arch: Arch.arm64, archName: 'arm64-v8a'),
    BuildItem(target: Target.android, arch: Arch.amd64, archName: 'x86_64'),
  ];

  static const String appName = 'FlClash';

  static const String coreName = 'FlClashCore';

  static const String libName = 'libclash';

  static String get outDir => join(current, libName);

  static String get _coreDir => join(current, 'core');

  static String get _servicesDir => join(current, 'services', 'helper');

  static String get distPath => join(current, 'dist');

  static String _getCc(BuildItem buildItem) {
    final environment = Platform.environment;
    if (buildItem.target == Target.android) {
      final ndk = environment['ANDROID_NDK'];
      assert(ndk != null);
      final prebuiltDir = Directory(
        join(ndk!, 'toolchains', 'llvm', 'prebuilt'),
      );
      final prebuiltDirList = prebuiltDir
          .listSync()
          .where((file) => !basename(file.path).startsWith('.'))
          .toList();
      final map = {
        'armeabi-v7a': 'armv7a-linux-androideabi21-clang',
        'arm64-v8a': 'aarch64-linux-android21-clang',
        'x86': 'i686-linux-android21-clang',
        'x86_64': 'x86_64-linux-android21-clang',
      };
      return join(prebuiltDirList.first.path, 'bin', map[buildItem.archName]);
    }
    return 'gcc';
  }

  static String get tags => 'with_gvisor';

  static Future<void> exec(
    List<String> executable, {
    String? name,
    Map<String, String>? environment,
    String? workingDirectory,
    bool runInShell = true,
  }) async {
    if (name != null) print('run $name');
    print('exec: ${executable.join(' ')}');
    print('env: ${environment.toString()}');
    final process = await Process.start(
      executable[0],
      executable.sublist(1),
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
    process.stdout.listen((data) {
      print(utf8.decode(data));
    });
    process.stderr.listen((data) {
      print(utf8.decode(data));
    });
    final exitCode = await process.exitCode;
    if (exitCode != 0 && name != null) throw '$name error';
  }

  static Future<String> calcSha256(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw 'File not exists';
    }
    final stream = file.openRead();
    return sha256.convert(await stream.reduce((a, b) => a + b)).toString();
  }

  static Future<List<String>> buildCore({
    required Mode mode,
    required Target target,
    Arch? arch,
    String coreBinaryName = coreName,
  }) async {
    final isLib = mode == Mode.lib;

    final items = buildItems.where((element) {
      return element.target == target &&
          (arch == null ? true : element.arch == arch);
    }).toList();

    final List<String> corePaths = [];

    final targetOutFilePath = join(outDir, target.name);
    final targetOutFile = File(targetOutFilePath);
    if (await targetOutFile.exists()) {
      await targetOutFile.delete(recursive: true);
      await Directory(targetOutFilePath).create(recursive: true);
    }
    for (final item in items) {
      final outFilePath = join(targetOutFilePath, item.archName);
      final file = File(outFilePath);
      if (file.existsSync()) {
        file.deleteSync(recursive: true);
      }

      final fileName = isLib
          ? '$libName${item.target.dynamicLibExtensionName}'
          : '$coreBinaryName${item.target.executableExtensionName}';
      final realOutPath = join(outFilePath, fileName);
      corePaths.add(realOutPath);

      final Map<String, String> env = {};
      env['GOOS'] = item.target.os;
      if (item.arch != null) {
        env['GOARCH'] = item.arch!.name;
      }
      if (isLib) {
        env['CGO_ENABLED'] = '1';
        env['CC'] = _getCc(item);
        env['CFLAGS'] = '-O3 -Werror';
      } else {
        env['CGO_ENABLED'] = '0';
      }
      final execLines = [
        'go',
        'build',
        '-ldflags=-w -s',
        '-tags=$tags',
        if (isLib) '-buildmode=c-shared',
        '-o',
        realOutPath,
      ];
      await exec(
        execLines,
        name: 'build core',
        environment: env,
        workingDirectory: _coreDir,
      );
      if (isLib && item.archName != null) {
        await adjustLibOut(
          targetOutFilePath: targetOutFilePath,
          outFilePath: outFilePath,
          archName: item.archName!,
        );
      }
    }

    return corePaths;
  }

  static Future<void> adjustLibOut({
    required String targetOutFilePath,
    required String outFilePath,
    required String archName,
  }) async {
    final includesPath = join(targetOutFilePath, 'includes');
    final realOutPath = join(includesPath, archName);
    await Directory(realOutPath).create(recursive: true);
    final targetOutFiles = Directory(outFilePath).listSync();
    final coreFiles = Directory(_coreDir).listSync();
    for (final file in [...targetOutFiles, ...coreFiles]) {
      if (!file.path.endsWith('.h')) {
        continue;
      }
      final targetFilePath = join(realOutPath, basename(file.path));
      final realFile = File(file.path);
      await realFile.copy(targetFilePath);
      if (coreFiles.contains(file)) {
        continue;
      }
      await realFile.delete();
    }
  }

  static Future<void> buildHelper({
    required Target target,
    required String token,
    required String serviceName,
    required int port,
  }) async {
    await exec(
      ['cargo', 'build', '--release', '--features', 'windows-service'],
      environment: {
        'TOKEN': token,
        'SERVICE_NAME': serviceName,
        'HELPER_PORT': port.toString(),
      },
      name: 'build helper',
      workingDirectory: _servicesDir,
    );
    final outPath = join(
      _servicesDir,
      'target',
      'release',
      'helper${target.executableExtensionName}',
    );
    final targetPath = join(
      outDir,
      target.name,
      '$serviceName${target.executableExtensionName}',
    );
    await File(outPath).copy(targetPath);
  }

  static List<String> getExecutable(String command) {
    return command.split(' ');
  }

  static Future<void> getDistributor() async {
    final distributorDir = join(
      current,
      'plugins',
      'flutter_distributor',
      'packages',
      'flutter_distributor',
    );

    await exec(
      name: 'clean distributor',
      Build.getExecutable('flutter clean'),
      workingDirectory: distributorDir,
    );
    await exec(
      name: 'upgrade distributor',
      Build.getExecutable('flutter pub upgrade'),
      workingDirectory: distributorDir,
    );
    await exec(
      name: 'get distributor',
      Build.getExecutable('dart pub global activate -s path $distributorDir'),
    );
  }

  static void copyFile(String sourceFilePath, String destinationFilePath) {
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      throw 'SourceFilePath not exists';
    }
    final destinationFile = File(destinationFilePath);
    final destinationDirectory = destinationFile.parent;
    if (!destinationDirectory.existsSync()) {
      destinationDirectory.createSync(recursive: true);
    }
    try {
      sourceFile.copySync(destinationFilePath);
      print('File copied successfully!');
    } catch (e) {
      print('Failed to copy file: $e');
    }
  }
}

class BuildCommand extends Command {
  Target target;

  BuildCommand({required this.target}) {
    argParser
      ..addOption('brand', help: 'Brand id (maps to .github/<brand>.json)')
      ..addOption('brand-file', help: 'Brand config json path');
    if (target == Target.android || target == Target.linux) {
      argParser.addOption(
        'arch',
        valueHelp: arches.map((e) => e.name).join(','),
        help: 'The $name build desc',
      );
    } else {
      argParser.addOption('arch', help: 'The $name build archName');
    }
    argParser.addOption(
      'out',
      valueHelp: [if (target.same) 'app', 'core'].join(','),
      help: 'The $name build arch',
    );
    argParser.addOption(
      'env',
      valueHelp: ['pre', 'stable'].join(','),
      help: 'The $name build env',
    );
  }

  @override
  String get description => 'build $name application';

  @override
  String get name => target.name;

  List<Arch> get arches => Build.buildItems
      .where((element) => element.target == target && element.arch != null)
      .map((e) => e.arch!)
      .toList();

  Future<void> _getLinuxDependencies(Arch arch) async {
    await Build.exec(Build.getExecutable('sudo apt update -y'));
    await Build.exec(
      Build.getExecutable('sudo apt install -y ninja-build libgtk-3-dev'),
    );
    await Build.exec(
      Build.getExecutable('sudo apt install -y libayatana-appindicator3-dev'),
    );
    await Build.exec(
      Build.getExecutable('sudo apt-get install -y libkeybinder-3.0-dev'),
    );
    await Build.exec(Build.getExecutable('sudo apt install -y locate'));
    if (arch == Arch.amd64) {
      await Build.exec(Build.getExecutable('sudo apt install -y rpm patchelf'));
      await Build.exec(Build.getExecutable('sudo apt install -y libfuse2'));

      final downloadName = arch == Arch.amd64 ? 'x86_64' : 'aarch64';
      await Build.exec(
        Build.getExecutable(
          'wget -O appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$downloadName.AppImage',
        ),
      );
      await Build.exec(Build.getExecutable('chmod +x appimagetool'));
      await Build.exec(
        Build.getExecutable('sudo mv appimagetool /usr/local/bin/'),
      );
    }
  }

  Future<void> _getMacosDependencies() async {
    await Build.exec(Build.getExecutable('npm install -g appdmg'));
  }

  String _escapeYamlSingleQuoted(String input) {
    return input.replaceAll("'", "''");
  }

  String _escapeCAndRcStringLiteral(String input) {
    return input.replaceAll('\\', r'\\').replaceAll('"', r'\"');
  }

  String _escapeXmlAttributeValue(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  String _resolvePath(String path) {
    if (path.isEmpty) return path;
    if (isAbsolute(path)) return path;
    return join(Directory.current.path, path);
  }

  Future<void> _updateDistributeOptions(BrandConfig brand) async {
    final file = File(join(Directory.current.path, 'distribute_options.yaml'));
    if (!file.existsSync()) return;
    final lines = await file.readAsLines();
    final updated = lines
        .map(
          (line) => line.trimLeft().startsWith('app_name:')
              ? "app_name: '${_escapeYamlSingleQuoted(brand.appName)}'"
              : line,
        )
        .join('\n');
    await file.writeAsString('$updated\n');
  }

  Future<void> _applyWindowsBranding(BrandConfig brand) async {
    final helperExeName = '${brand.windowsHelperServiceName}.exe';

    final companyName = brand.id == defaultBrandId ? 'com.follow' : brand.id;
    final productName = brand.id == defaultBrandId
        ? 'clash'
        : brand.windowsBinaryName;

    final brandingHeader =
        '''
#pragma once

// Generated by setup.dart. Do not edit by hand.

#define BRAND_APP_NAME "${_escapeCAndRcStringLiteral(brand.appName)}"
#define BRAND_APP_NAME_W L"${_escapeCAndRcStringLiteral(brand.appName)}"

#define BRAND_COMPANY_NAME "${_escapeCAndRcStringLiteral(companyName)}"
#define BRAND_PRODUCT_NAME "${_escapeCAndRcStringLiteral(productName)}"
#define BRAND_INTERNAL_NAME "${_escapeCAndRcStringLiteral(productName)}"
#define BRAND_ORIGINAL_FILENAME "${_escapeCAndRcStringLiteral(brand.windowsExecutableName)}"
#define BRAND_LEGAL_COPYRIGHT "Copyright (C) 2023 ${_escapeCAndRcStringLiteral(companyName)}. All rights reserved."
''';

    await File(
      join(Directory.current.path, 'windows', 'runner', 'branding.h'),
    ).writeAsString(brandingHeader);

    final repoParts = brand.repository.split('/');
    final windowsPublisher =
        repoParts.isNotEmpty && repoParts.first.trim().isNotEmpty
        ? repoParts.first.trim()
        : 'chen08209';
    final windowsPublisherUrl = 'https://github.com/${brand.repository}';

    final makeConfig =
        '''
script_template: inno_setup.iss
app_id: ${brand.windowsAppId}
app_name: ${brand.windowsBinaryName}
publisher: $windowsPublisher
publisher_url: $windowsPublisherUrl
display_name: '${_escapeYamlSingleQuoted(brand.appName)}'
executable_name: ${brand.windowsExecutableName}
output_base_file_name: ${brand.windowsExecutableName}
setup_icon_file: ..\\windows\\runner\\resources\\app_icon.ico
locales:
  - lang: zh
    file: ..\\windows\\packaging\\exe\\ChineseSimplified.isl
  - lang: en
privileges_required: admin
''';
    await File(
      join(
        Directory.current.path,
        'windows',
        'packaging',
        'exe',
        'make_config.yaml',
      ),
    ).writeAsString(makeConfig);

    final innoSetupPath = join(
      Directory.current.path,
      'windows',
      'packaging',
      'exe',
      'inno_setup.iss',
    );
    if (File(innoSetupPath).existsSync()) {
      final content = await File(innoSetupPath).readAsString();
      final updated = content.replaceAll(
        RegExp(r'Processes := \[[^\]]*\];'),
        "Processes := ['${brand.windowsExecutableName}', '${brand.windowsCoreExecutableName}', '$helperExeName'];",
      );
      await File(innoSetupPath).writeAsString(updated);
    }

    if (brand.windowsAppIconIco != null) {
      final iconSrc = File(_resolvePath(brand.windowsAppIconIco!));
      if (iconSrc.existsSync()) {
        await iconSrc.copy(
          join(
            Directory.current.path,
            'windows',
            'runner',
            'resources',
            'app_icon.ico',
          ),
        );
      }
    }
  }

  Future<void> _applyTrayAssets(BrandConfig brand) async {
    if (brand.trayAssetDir == null) return;
    final source = Directory(_resolvePath(brand.trayAssetDir!));
    final dest = Directory(
      join(Directory.current.path, 'assets', 'images', 'icon'),
    );
    if (!source.existsSync()) return;
    for (final entity in source.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relative = relativePath(entity.path, from: source.path);
      final targetFile = File(join(dest.path, relative));
      await targetFile.parent.create(recursive: true);
      await File(entity.path).copy(targetFile.path);
    }
  }

  String relativePath(String path, {required String from}) {
    return relative(path, from: from);
  }

  String _sanitizeMacosAppBundleName(String name) {
    final sanitized = name
        .trim()
        .replaceAll(RegExp(r'[\r\n\t]'), ' ')
        .replaceAll(RegExp(r'[\\\\/:]'), '-')
        .replaceAll(RegExp(r' +'), ' ');
    return sanitized.isEmpty ? 'FlClash' : sanitized;
  }

  String _quotePbxprojString(String value) {
    final escaped = value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return '"$escaped"';
  }

  String _replaceBetweenMarkers({
    required String content,
    required String beginMarker,
    required String endMarker,
    required String replacement,
  }) {
    final beginIndex = content.indexOf(beginMarker);
    final endIndex = content.indexOf(endMarker);
    if (beginIndex == -1 || endIndex == -1 || endIndex < beginIndex) {
      throw 'Markers not found: $beginMarker ... $endMarker';
    }
    final start = beginIndex + beginMarker.length;
    return content.replaceRange(start, endIndex, '\n$replacement\n');
  }

  Future<void> _applyAndroidBranding(BrandConfig brand) async {
    final applicationId = brand.androidApplicationId;
    if (applicationId == null || applicationId.trim().isEmpty) {
      throw 'Android application_id is required for brand "${brand.id}"';
    }

    final localPropertiesPath = join(
      Directory.current.path,
      'android',
      'local.properties',
    );
    final localPropertiesFile = File(localPropertiesPath);
    final lines = localPropertiesFile.existsSync()
        ? await localPropertiesFile.readAsLines()
        : <String>[];
    final updatedLines = <String>[
      for (final line in lines)
        if (!line.trimLeft().startsWith('brand.applicationId=') &&
            !line.trimLeft().startsWith('brand.appName='))
          line,
      'brand.applicationId=$applicationId',
      'brand.appName=${brand.appName}',
    ];
    await localPropertiesFile.writeAsString('${updatedLines.join('\n')}\n');

    final manifestPath = join(
      Directory.current.path,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    );
    if (File(manifestPath).existsSync()) {
      final begin = '<!-- BRAND:URL_SCHEMES_BEGIN -->';
      final end = '<!-- BRAND:URL_SCHEMES_END -->';
      final schemeLines = brand.urlSchemes
          .map(
            (s) =>
                '                <data android:scheme="${_escapeXmlAttributeValue(s)}" />',
          )
          .join('\n');
      final content = await File(manifestPath).readAsString();
      final updated = _replaceBetweenMarkers(
        content: content,
        beginMarker: begin,
        endMarker: end,
        replacement: schemeLines,
      );
      await File(manifestPath).writeAsString(updated);
    }

    if (brand.androidResDir != null) {
      final source = Directory(_resolvePath(brand.androidResDir!));
      final dest = Directory(
        join(Directory.current.path, 'android', 'app', 'src', 'main', 'res'),
      );
      if (source.existsSync()) {
        final mipmapDirs = [
          'mipmap-mdpi',
          'mipmap-hdpi',
          'mipmap-xhdpi',
          'mipmap-xxhdpi',
          'mipmap-xxxhdpi',
        ];
        final iconBaseNames = {
          'ic_launcher',
          'ic_launcher_round',
          'ic_launcher_foreground',
        };
        for (final dirName in mipmapDirs) {
          final dir = Directory(join(dest.path, dirName));
          if (!dir.existsSync()) continue;
          for (final entity in dir.listSync()) {
            if (entity is! File) continue;
            final base = basenameWithoutExtension(entity.path);
            if (!iconBaseNames.contains(base)) continue;
            await entity.delete();
          }
        }
        for (final entity in source.listSync(recursive: true)) {
          if (entity is! File) continue;
          final relative = relativePath(entity.path, from: source.path);
          final targetFile = File(join(dest.path, relative));
          await targetFile.parent.create(recursive: true);
          await File(entity.path).copy(targetFile.path);
        }
      }
    }
  }

  Future<void> _applyMacosBranding(BrandConfig brand) async {
    final bundleId = brand.macosBundleId;
    if (bundleId == null || bundleId.isEmpty) {
      throw 'macOS bundle_id is required for brand "${brand.id}"';
    }

    final appBundleName = _sanitizeMacosAppBundleName(brand.appName);

    final appInfoPath = join(
      Directory.current.path,
      'macos',
      'Runner',
      'Configs',
      'AppInfo.xcconfig',
    );
    if (File(appInfoPath).existsSync()) {
      final lines = await File(appInfoPath).readAsLines();
      final updatedLines = <String>[];
      var hasModuleName = false;
      for (final line in lines) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('PRODUCT_NAME =')) {
          updatedLines.add('PRODUCT_NAME = $appBundleName');
          continue;
        }
        if (trimmed.startsWith('PRODUCT_BUNDLE_IDENTIFIER =')) {
          updatedLines.add('PRODUCT_BUNDLE_IDENTIFIER = $bundleId');
          continue;
        }
        if (trimmed.startsWith('PRODUCT_MODULE_NAME =')) {
          hasModuleName = true;
        }
        updatedLines.add(line);
      }
      if (!hasModuleName) {
        updatedLines.add('');
        updatedLines.add('PRODUCT_MODULE_NAME = FlClash');
      }
      await File(appInfoPath).writeAsString('${updatedLines.join('\n')}\n');
    }

    final infoPlistPath = join(
      Directory.current.path,
      'macos',
      'Runner',
      'Info.plist',
    );
    if (File(infoPlistPath).existsSync()) {
      final begin = '<!-- BRAND:URL_SCHEMES_BEGIN -->';
      final end = '<!-- BRAND:URL_SCHEMES_END -->';
      final schemeLines = brand.urlSchemes
          .map(
            (s) =>
                '\t\t\t\t\t<string>${_escapeCAndRcStringLiteral(s)}</string>',
          )
          .join('\n');
      final content = await File(infoPlistPath).readAsString();
      final updated = _replaceBetweenMarkers(
        content: content,
        beginMarker: begin,
        endMarker: end,
        replacement: schemeLines,
      );
      await File(infoPlistPath).writeAsString(updated);
    }

    final pbxprojPath = join(
      Directory.current.path,
      'macos',
      'Runner.xcodeproj',
      'project.pbxproj',
    );
    if (File(pbxprojPath).existsSync()) {
      final content = await File(pbxprojPath).readAsString();
      final appBundleFileName = '$appBundleName.app';
      final updated = content
          .replaceAll(
            'PRODUCT_BUNDLE_IDENTIFIER = com.follow.clash.debug;',
            'PRODUCT_BUNDLE_IDENTIFIER = $bundleId.debug;',
          )
          .replaceAll(
            'PRODUCT_BUNDLE_IDENTIFIER = com.follow.clash;',
            'PRODUCT_BUNDLE_IDENTIFIER = $bundleId;',
          )
          .replaceAll(
            'path = FlClash.app;',
            'path = ${_quotePbxprojString(appBundleFileName)};',
          )
          .replaceAll('FlClash.app', appBundleFileName);
      await File(pbxprojPath).writeAsString(updated);
    }

    final xcschemePath = join(
      Directory.current.path,
      'macos',
      'Runner.xcodeproj',
      'xcshareddata',
      'xcschemes',
      'Runner.xcscheme',
    );
    if (File(xcschemePath).existsSync()) {
      final content = await File(xcschemePath).readAsString();
      final updated = content.replaceAll('FlClash.app', '$appBundleName.app');
      await File(xcschemePath).writeAsString(updated);
    }

    final dmgConfigPath = join(
      Directory.current.path,
      'macos',
      'packaging',
      'dmg',
      'make_config.yaml',
    );
    if (File(dmgConfigPath).existsSync()) {
      final content = await File(dmgConfigPath).readAsString();
      final updated = content
          .replaceAll(
            RegExp(r'^title:.*$', multiLine: true),
            'title: $appBundleName',
          )
          .replaceAll(
            RegExp(r'^\\s*path:.*\\.app\\s*$', multiLine: true),
            '    path: $appBundleName.app',
          );
      await File(dmgConfigPath).writeAsString(updated);
    }

    if (brand.macosAppIconsetDir != null) {
      final source = Directory(_resolvePath(brand.macosAppIconsetDir!));
      final dest = Directory(
        join(
          Directory.current.path,
          'macos',
          'Runner',
          'Assets.xcassets',
          'AppIcon.appiconset',
        ),
      );
      if (source.existsSync()) {
        for (final entity in source.listSync(recursive: true)) {
          if (entity is! File) continue;
          final relative = relativePath(entity.path, from: source.path);
          final targetFile = File(join(dest.path, relative));
          await targetFile.parent.create(recursive: true);
          await File(entity.path).copy(targetFile.path);
        }
      }
    }
  }

  Future<void> _buildDistributor({
    required Target target,
    required String targets,
    required String env,
    required BrandConfig brand,
    List<String> flutterBuildArgs = const ['verbose'],
    List<String> distributorArgs = const [],
    Map<String, String> extraDartDefines = const {},
    Map<String, String>? environment,
  }) async {
    await Build.getDistributor();
    final args = <String>[
      'flutter_distributor',
      'package',
      '--skip-clean',
      '--platform',
      target.name,
      '--targets',
      targets,
      if (flutterBuildArgs.isNotEmpty)
        '--flutter-build-args=${flutterBuildArgs.join(',')}',
      ...distributorArgs,
      ...brand.dartDefines.entries.map(
        (e) => '--build-dart-define=${e.key}=${e.value}',
      ),
      ...extraDartDefines.entries.map(
        (e) => '--build-dart-define=${e.key}=${e.value}',
      ),
      '--build-dart-define=APP_ENV=$env',
    ];
    await Build.exec(name: name, args, environment: environment);
  }

  Future<String?> get systemArch async {
    if (Platform.isWindows) {
      return Platform.environment['PROCESSOR_ARCHITECTURE'];
    } else if (Platform.isLinux || Platform.isMacOS) {
      final result = await Process.run('uname', ['-m']);
      return result.stdout.toString().trim();
    }
    return null;
  }

  @override
  Future<void> run() async {
    final mode = target == Target.android ? Mode.lib : Mode.core;
    final String out = argResults?['out'] ?? (target.same ? 'app' : 'core');
    final String? archName = argResults?['arch'] as String?;
    final env = argResults?['env'] ?? 'pre';
    final brandId = argResults?['brand'] as String? ?? defaultBrandId;
    final brandFile = argResults?['brand-file'] as String?;
    final brand = await BrandConfig.load(
      brandId: brandId,
      brandFilePath: brandFile,
    );
    final currentArches = arches
        .where((element) => element.name == archName)
        .toList();
    final arch = currentArches.isEmpty ? null : currentArches.first;

    if (arch == null && target != Target.android) {
      throw 'Invalid arch parameter';
    }

    final corePaths = await Build.buildCore(
      target: target,
      arch: arch,
      mode: mode,
      coreBinaryName: target == Target.windows
          ? brand.windowsCoreBinaryName
          : Build.coreName,
    );

    if (out != 'app') {
      return;
    }

    await _updateDistributeOptions(brand);
    await _applyTrayAssets(brand);

    switch (target) {
      case Target.windows:
        await _applyWindowsBranding(brand);
        final token = await Build.calcSha256(corePaths.first);
        await Build.buildHelper(
          target: target,
          token: token,
          serviceName: brand.windowsHelperServiceName,
          port: brand.windowsHelperPort,
        );
        await _buildDistributor(
          target: target,
          targets: 'exe,zip',
          distributorArgs: ['--description', archName!],
          extraDartDefines: {'CORE_SHA256': token},
          environment: {
            'FLCLASH_BINARY_NAME': brand.windowsBinaryName,
            'FLCLASH_CORE_EXE': brand.windowsCoreExecutableName,
            'FLCLASH_HELPER_EXE': '${brand.windowsHelperServiceName}.exe',
          },
          env: env,
          brand: brand,
        );
        return;
      case Target.linux:
        final targetMap = {Arch.arm64: 'linux-arm64', Arch.amd64: 'linux-x64'};
        final targets = [
          'deb',
          if (arch == Arch.amd64) 'appimage',
          if (arch == Arch.amd64) 'rpm',
        ].join(',');
        final defaultTarget = targetMap[arch];
        await _getLinuxDependencies(arch!);
        await _buildDistributor(
          target: target,
          targets: targets,
          distributorArgs: [
            '--description',
            archName!,
            '--build-target-platform',
            defaultTarget!,
          ],
          env: env,
          brand: brand,
        );
        return;
      case Target.android:
        final targetMap = {
          Arch.arm: 'android-arm',
          Arch.arm64: 'android-arm64',
          Arch.amd64: 'android-x64',
        };
        final defaultArches = [Arch.arm, Arch.arm64, Arch.amd64];
        final defaultTargets = defaultArches
            .where((element) => arch == null ? true : element == arch)
            .map((e) => targetMap[e])
            .toList();
        await _applyAndroidBranding(brand);
        await _buildDistributor(
          target: target,
          targets: 'apk',
          flutterBuildArgs: ['verbose', 'split-per-abi'],
          distributorArgs: [
            '--build-target-platform',
            defaultTargets.join(','),
          ],
          env: env,
          brand: brand,
        );
        return;
      case Target.macos:
        await _getMacosDependencies();
        await _applyMacosBranding(brand);
        await _buildDistributor(
          target: target,
          targets: 'dmg',
          distributorArgs: ['--description', archName!],
          env: env,
          brand: brand,
        );
        return;
    }
  }
}

Future<void> main(Iterable<String> args) async {
  final runner = CommandRunner('setup', 'build Application');
  runner.addCommand(BuildCommand(target: Target.android));
  runner.addCommand(BuildCommand(target: Target.linux));
  runner.addCommand(BuildCommand(target: Target.windows));
  runner.addCommand(BuildCommand(target: Target.macos));
  runner.run(args);
}
