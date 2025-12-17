# White Label（白标）改造说明

这份文档说明本仓库已做的白标改造点、如何通过 Tag + JSON 配置驱动定制编译，以及为保证多个白标 App 可以“共存且互不污染”所做的隔离点（工作目录、端口、Helper 等）。

## 如何触发 GitHub CI 自动编译

- CI 触发条件：`.github/workflows/build.yaml` 只在 `push tags: v*` 时触发。
- 白标选择规则：Tag 名字如果包含 `+`，则取 `+` 之后的内容作为 `BRAND_ID`。
  - 示例：`v1.2.3+first` 会加载 `.github/first.json` 并按其中配置进行定制编译。
  - 示例：`v1.2.3`（没有 `+`）默认使用内置 `flclash` 品牌（等价于 `.github/flclash.json` 不存在时的默认配置）。

本地推 Tag 的典型命令：

```bash
git tag v1.2.3+first
git push origin v1.2.3+first
```

## CI 需要准备哪些 Secrets（哪些是可选的）

仅“编译出产物并上传 Actions Artifact”，理论上不需要任何 Secrets（子模块已改为 HTTPS，不再依赖 SSH Key）。

如果你希望 CI 产物更完整/发布更自动化，可选准备：

- Android 签名（可选；不提供则用 debug key 签名 release 构建，仍能编译出 APK）
  - `KEYSTORE`：`android/app/keystore.jks` 的 base64
  - `KEY_ALIAS` / `STORE_PASSWORD` / `KEY_PASSWORD`
- Firebase（可选；不提供则跳过 google-services 相关插件）
  - `SERVICE_JSON`：`android/app/google-services.json` 的 base64
- Telegram 推送（可选；只有你需要 workflow 里的推送步骤才需要）
  - `TELEGRAM_BOT_TOKEN` / `TELEGRAM_API_ID` / `TELEGRAM_API_HASH`
- 推送到另一个仓库（可选；workflow 里用于 fdroid repo）
  - `SSH_DEPLOY_KEY`

## google-services.json 要填什么？如何申请？免费吗？

- `google-services.json` 不是“手填”，而是从 Firebase 控制台下载的配置文件。
- 获取方式：
  1. 打开 Firebase Console → 创建/选择项目
  2. 添加 Android App（包名必须与白标的 `applicationId` 一致）
  3. 下载 `google-services.json` 放到 `android/app/google-services.json`
  4. CI 场景可将其 base64 后存到 Secrets（本项目用 `SERVICE_JSON`）
- 是否免费：
  - Firebase 有免费额度（Spark 计划），Crashlytics/Analytics 通常可免费使用；超出免费额度的服务会计费，具体以 Firebase 控制台为准。

---

## Windows：修改了哪些（用于共存/不污染）

**目标**：不同白标在 Windows 上可以同时安装、同时运行，且互不影响（尤其是 Helper Service 名称、端口、核心可执行文件名等）。

- `windows/CMakeLists.txt`
  - 支持通过环境变量覆盖 `BINARY_NAME`（应用 exe 名），以及打包时附带的核心/Helper 可执行文件名：
    - `FLCLASH_BINARY_NAME`
    - `FLCLASH_CORE_EXE`
    - `FLCLASH_HELPER_EXE`
  - 这些环境变量由 `setup.dart` 在 CI 构建时注入，确保不同白标生成不同的 exe 名（从而让 OS 的 App 数据目录/安装产物也更容易区分）。

- `windows/runner/main.cpp`
  - 引入 `windows/runner/branding.h`，窗口标题改为 `BRAND_APP_NAME_W`，避免固定写死 `FlClash`。

- `windows/runner/Runner.rc`
  - 引入 `windows/runner/branding.h`，文件版本信息（CompanyName、ProductName、OriginalFilename 等）全部品牌化。

- `windows/runner/branding.h`
  - 新增默认品牌头文件（本地开发可直接编译）。
  - CI/打包时会被 `dart setup.dart ... --brand <id>` 覆盖为品牌配置内容。

- `services/helper/src/service/windows.rs` + `services/helper/src/service/hub.rs`
  - Helper Service 名称与监听端口改为编译期注入：
    - `SERVICE_NAME`
    - `HELPER_PORT`
  - 这能保证不同白标安装后的 Windows Service 可以同时存在、互不覆盖，并且本地端口不冲突。

- `setup.dart`
  - 增加 `BrandConfig`（从 `.github/<brand>.json` 读取）。
  - 为了避免“不同品牌 appName 恰好相同”导致 Windows Service/EXE 名称冲突：非默认品牌在未显式指定 `windows.binary_name` 时，会默认使用 `"<appName>-<brandId>"` 作为二进制名派生基础；如果你手动指定了 `windows.binary_name`，请确保不同品牌之间唯一，或同时指定 `windows.helper_service_name`。
  - Windows 侧会自动应用：
    - 生成 `windows/runner/branding.h`
    - 写入 `windows/packaging/exe/make_config.yaml`（Inno Setup 参数）
    - 更新 `windows/packaging/exe/inno_setup.iss` 的进程列表
    - 可选覆盖 `windows/runner/resources/app_icon.ico`
    - 编译并注入品牌化的 Helper（服务名/端口一致）

- `lib/common/path.dart`
  - 非默认品牌会把应用数据目录/缓存/临时目录统一落到 `.../brands/<brandId>/` 子目录，避免在少数平台/打包形态下出现路径相同导致的配置/锁文件互相影响。

- `lib/state.dart`
  - 强制把 Clash 配置中的 `dns.listen` 绑定到品牌端口（由 `DNS_LISTEN_PORT` 决定；默认按 brandId hash 派生），避免多个白标同时运行时因为默认 `0.0.0.0:1053` 冲突导致核心启动失败。

---

## macOS：修改了哪些（用于共存/不污染）

**目标**：不同白标在 macOS 上可以同时安装、同时运行，且互不影响（BundleId、URL Schemes、App 名称、图标等）。

- `macos/Runner/Info.plist`
  - 增加 `<!-- BRAND:URL_SCHEMES_BEGIN/END -->` 标记，供 `setup.dart` 在构建时写入品牌的 URL Schemes。

- `setup.dart`
  - 自动更新：
    - `macos/Runner/Configs/AppInfo.xcconfig`：`PRODUCT_NAME`、`PRODUCT_BUNDLE_IDENTIFIER`
    - `macos/Runner.xcodeproj/project.pbxproj`：debug/release 的 bundle id、`.app` 名称
    - `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`：`.app` 名称
    - `macos/packaging/dmg/make_config.yaml`：DMG 标题与 app 路径
    - 可选覆盖 `macos/Runner/Assets.xcassets/AppIcon.appiconset/`（App 图标）

- `lib/common/path.dart`
  - 非默认品牌会把应用数据目录/缓存/临时目录统一落到 `.../brands/<brandId>/` 子目录，进一步保证多白标同时运行时不会读写到同一份数据。

- `lib/common/constant.dart`
  - macOS/桌面端与核心通信使用 unix domain socket；socket 路径现在包含品牌信息并做了长度限制，避免不同白标并行启动时 socket 文件互相覆盖或触发路径长度上限。

---

## Android：修改了哪些（用于共存/不污染）

**目标**：不同白标在 Android 上可以同时安装、同时运行，且互不影响（包名、深链 Scheme、通知标题、VPN Session 名称、资源图标等）。

- `android/app/build.gradle.kts`
  - **无 `google-services.json` 时跳过插件**：
    - `com.google.gms.google-services` / `com.google.firebase.crashlytics` 仅在 `google-services.json` 存在时才 `apply`。
  - 支持白标注入：
    - 从 `android/local.properties` 读取 `brand.applicationId` / `brand.appName`
    - `applicationId` 与 `@string/app_name`（通过 `resValue`）随品牌变化

- `android/app/src/main/AndroidManifest.xml`
  - `android:label` 使用 `@string/app_name`，随品牌变化。
  - 深链 URL Schemes 增加 `<!-- BRAND:URL_SCHEMES_BEGIN/END -->` 标记，供 `setup.dart` 注入。
  - 多处 action/permission 使用 `${applicationId}` 占位符，确保不同包名下广播/权限不会互相冲突。

- `setup.dart`
  - Android 构建前自动：
    - 写入 `android/local.properties`：`brand.applicationId`、`brand.appName`
    - 替换 Manifest 里的 URL Schemes（保证不同白标不会抢同一个 scheme）
    - 可选复制 `android_res_dir` 到 `android/app/src/main/res/`（覆盖 launcher icon、通知 icon 等资源）

- `android/common/.../GlobalState.kt`
  - `google-services.json` 缺失时（Firebase 未配置）会自动跳过 Crashlytics 初始化，避免因为缺少默认 FirebaseApp 导致运行时崩溃。

- Android Service 侧品牌化（避免系统 UI 仍显示 FlClash）
  - `android/service/.../NotificationModule.kt`：通知标题使用应用 Label（`loadLabel`），空标题时自动 fallback。
  - `android/service/.../NotificationParams.kt`：默认 title 改为空字符串。
  - `android/service/.../VpnService.kt`：VPN `setSession()` 改为应用 Label。
  - `android/service/.../FilesProvider.kt`：DocumentsProvider 根目录标题改为应用 Label。
  - `android/app/.../models/State.kt`：默认 `currentProfileName` 改为空字符串，避免首次同步时写死 FlClash。

---

## 白标配置文件格式（.github/<brand>.json）

CI 会按 Tag 解析出的 `BRAND_ID` 加载 `.github/<BRAND_ID>.json`，示例请看 `.github/first.json`（可按需增减字段）。

常用字段（全部可选，未填会走默认/派生值）：

- 顶层：`app_name` / `repository` / `url_schemes`
- `android.application_id`
- `macos.bundle_id`
- `windows.*`（exe 名称、service 名称、端口等）
- `ports.*`（mixed/external-controller/dns_listen/helper）
- `assets.icon`（推荐）：一个 PNG 的 URL/本地路径，用于自动生成 tray/windows/macOS/android 所需图标素材（CI 会执行 `dart run tool/generate_brand_assets.dart --brand <id>` 生成到 `brands/<id>/...`，`setup.dart` 会自动拾取并应用）。
- `assets.*`（可选；高级用法）：`tray_asset_dir` / `windows_app_icon_ico` / `macos_app_iconset_dir` / `android_res_dir` 等，手动指定素材路径覆盖默认规则。
