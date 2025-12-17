// ignore_for_file: constant_identifier_names

import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/material.dart';

const brandId = String.fromEnvironment('BRAND_ID', defaultValue: 'flclash');
const appName = String.fromEnvironment('APP_NAME', defaultValue: 'FlClash');
const appHelperService = String.fromEnvironment(
  'APP_HELPER_SERVICE',
  defaultValue: 'FlClashHelperService',
);
const coreName = 'clash.meta';
const browserUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const packageName = 'com.follow.clash';

String _buildUnixSocketPath() {
  final safeBrand = brandId.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  final randHex = Random().nextInt(0x7fffffff).toRadixString(16);

  // Keep it short to avoid hitting unix domain socket path limits (~100 bytes).
  const prefix = '/tmp/flclash_';
  final suffix = '_$randHex.sock';
  const maxTotal = 100;

  final maxBrandLen = maxTotal - prefix.length - suffix.length;
  final brandPart = maxBrandLen > 0
      ? (safeBrand.length > maxBrandLen
            ? safeBrand.substring(0, maxBrandLen)
            : safeBrand)
      : '';
  final effectiveBrandPart = brandPart.isEmpty ? 'socket' : brandPart;

  return '$prefix$effectiveBrandPart$suffix';
}

final unixSocketPath = _buildUnixSocketPath();
const helperPort = int.fromEnvironment('HELPER_PORT', defaultValue: 47890);
const dnsListenPort = int.fromEnvironment('DNS_LISTEN_PORT', defaultValue: 1053);
const defaultDnsListen = '0.0.0.0:$dnsListenPort';
const maxTextScale = 1.4;
const minTextScale = 0.8;
final baseInfoEdgeInsets = EdgeInsets.symmetric(
  vertical: 16.ap,
  horizontal: 16.ap,
);
final listHeaderPadding = EdgeInsets.only(
  left: 16.ap,
  right: 8.ap,
  top: 24.ap,
  bottom: 8.ap,
);

final defaultTextScaleFactor =
    WidgetsBinding.instance.platformDispatcher.textScaleFactor;
const httpTimeoutDuration = Duration(milliseconds: 5000);
const moreDuration = Duration(milliseconds: 100);
const animateDuration = Duration(milliseconds: 100);
const midDuration = Duration(milliseconds: 200);
const commonDuration = Duration(milliseconds: 300);
const defaultUpdateDuration = Duration(days: 1);
const MMDB = 'GEOIP.metadb';
const ASN = 'ASN.mmdb';
const GEOIP = 'GEOIP.dat';
const GEOSITE = 'GEOSITE.dat';
final double kHeaderHeight = system.isDesktop
    ? !system.isMacOS
          ? 40
          : 28
    : 0;
const profilesDirectoryName = 'profiles';
const localhost = '127.0.0.1';
const clashConfigKey = 'clash_config';
const configKey = 'config';
const double dialogCommonWidth = 300;
const repository = String.fromEnvironment(
  'REPOSITORY',
  defaultValue: 'chen08209/FlClash',
);

const protocolSchemesCsv = String.fromEnvironment(
  'PROTOCOL_SCHEMES',
  defaultValue: 'clash,clashmeta,flclash',
);

List<String> get protocolSchemes => protocolSchemesCsv
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList(growable: false);
const defaultExternalController = '127.0.0.1:9090';
const maxMobileWidth = 600;
const maxLaptopWidth = 840;
const defaultTestUrl = 'https://www.gstatic.com/generate_204';
final commonFilter = ImageFilter.blur(
  sigmaX: 5,
  sigmaY: 5,
  tileMode: TileMode.mirror,
);

const navigationItemListEquality = ListEquality<NavigationItem>();
const trackerInfoListEquality = ListEquality<TrackerInfo>();
const stringListEquality = ListEquality<String>();
const intListEquality = ListEquality<int>();
const logListEquality = ListEquality<Log>();
const groupListEquality = ListEquality<Group>();
const ruleListEquality = ListEquality<Rule>();
const scriptEquality = ListEquality<Script>();
const externalProviderListEquality = ListEquality<ExternalProvider>();
const packageListEquality = ListEquality<Package>();
const hotKeyActionListEquality = ListEquality<HotKeyAction>();
const stringAndStringMapEquality = MapEquality<String, String>();
const stringAndStringMapEntryListEquality =
    ListEquality<MapEntry<String, String>>();
const stringAndStringMapEntryIterableEquality =
    IterableEquality<MapEntry<String, String>>();
const delayMapEquality = MapEquality<String, Map<String, int?>>();
const stringSetEquality = SetEquality<String>();
const keyboardModifierListEquality = SetEquality<KeyboardModifier>();

const viewModeColumnsMap = {
  ViewMode.mobile: [2, 1],
  ViewMode.laptop: [3, 2],
  ViewMode.desktop: [4, 3],
};

const proxiesListStoreKey = PageStorageKey<String>('proxies_list');
const toolsStoreKey = PageStorageKey<String>('tools');
const profilesStoreKey = PageStorageKey<String>('profiles');

const defaultPrimaryColor = 0XFFD8C0C3;

double getWidgetHeight(num lines) {
  return max(lines * 80 + (lines - 1) * 16, 0).ap;
}

const maxLength = 1000;

final mainIsolate = 'FlClashMainIsolate';

final serviceIsolate = 'FlClashServiceIsolate';

const defaultPrimaryColors = [
  0xFF795548,
  0xFF03A9F4,
  0xFFFFFF00,
  0XFFBBC9CC,
  0XFFABD397,
  defaultPrimaryColor,
  0XFF665390,
];

const scriptTemplate = '''
const main = (config) => {
  return config;
}''';
