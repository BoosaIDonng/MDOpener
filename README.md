# MD Opener

> 官网：[mdopener.honlnk.com](https://mdopener.honlnk.com)

一个轻量、纯粹的 Android Markdown 查看器。装上之后，在任意文件管理器里点击 `.md` / `.markdown` / `.mdown` 文件，即可用本应用打开并查看渲染后的内容。

无联网权限、无广告、无后台行为——只做一件事：把 Markdown 漂亮地显示出来。

## 功能特性

- 📂 **系统级关联**：注册为 `.md / .markdown / .mdown` 文件的默认打开方式（大小写扩展名均可），支持 `content://` 与 `file://` 两种来源；`pathPattern` 对 `a.b.md` 这类多点文件名逐级枚举，按扩展名 / 按 MIME 的文件管理器均有兜底
- 🔗 **多入口**：从文件管理器「打开」（`ACTION_VIEW`）、接收其他应用「分享」（`ACTION_SEND`，纯文本 `EXTRA_TEXT` 亦可直接渲染），以及从桌面图标启动进入首页自选文件
- 🔙 **分级返回**：从外部应用直接打开的文档，按系统返回直接退出回到来源应用；应用内打开的文档、设置页则逐级退回上一页
- 🕘 **最近文档**：主页右上角可一键重开刚关闭的文档（仅保留在本次运行的内存中，退出 App 即清空）
- 🎨 **主题**：跟随系统 / 浅色 / 深色；「暖纸 / 深炭」双配色取自正文排版主题，应用外壳与内容同一视觉语言
- 🔤 **可调字号**：12sp – 28sp
- 📏 **正文宽度**：240dp – 1100dp，适配手机与平板；设置值超过当前屏幕宽度时设置页会提示（该档位面向更宽设备）
- 📑 **目录（TOC）**：自动提取标题，点击快速跳转
- 🔍 **页内搜索**：实时高亮匹配，显示命中数量
- 🖼️ **相对图片解析**：支持 `![](./images/a.png)` 这类同级目录引用（file:// 与树形 DocumentsProvider 的 content:// 均可）
- 💬 **GitHub 风格提示框**：行首 `> [!NOTE]` / `> [!TIP]` 等 callout 语法渲染为提示框（仅行首匹配，行内代码中的同款文本不误判）
- 🌏 **编码检测**：BOM 嗅探 → UTF-8 严格校验 → GB18030 回退（覆盖 GBK / GB2312），中文老文件不乱码
- 📄 **导出 PDF**：另存为 .pdf 文件（纸张 A4/A5/B5/Letter/Legal、页边距、矢量文字可选中、可选整页背景色、导出后自动打开），自动展开折叠内容，智能分页且支持 `---` 分割线强制分页
- 🧩 **代码高亮**：GitHub 风格（浅 / 深双主题），基于 highlight.js
- 🔎 **检查更新**：设置页显示当前版本，一键跳转 GitHub Releases 查看并下载最新版（应用本体保持零联网权限）

## 下载

在 [GitHub Releases](https://github.com/honlnk/MDOpener/releases) 下载最新 APK，签名固定，可直接覆盖安装。

### iOS（侧载版）

iOS 版不走 App Store，面向侧载场景：从 [Releases](https://github.com/honlnk/MDOpener/releases) 的 `ios-v*` 预发布版（或 [Actions](https://github.com/honlnk/MDOpener/actions/workflows/build-ios.yml) 运行页产物）下载 `MD-Opener-ios-*.ipa`，用 AltStore / Sideloadly / TrollStore 等工具以自己的 Apple ID 重签安装。功能与安卓版对齐；相对路径图片因 iOS 沙盒需在提示时授权所在文件夹（仅需一次）。

## 技术栈

- **Kotlin** + **Jetpack Compose**（Material 3）
- 渲染引擎：WebView + [marked](https://github.com/markedjs/marked) + [highlight.js](https://highlightjs.org/)
- 设置持久化：Jetpack DataStore (Preferences)
- 最低支持：Android 7.0（API 24）
- 目标 SDK：Android 14（API 34）

## 项目结构

单仓库多平台（monorepo）：`web/` 为双端共享的渲染资产唯一来源，`android/` 与 `ios/` 分别为两端原生壳。

```
├── android/src/main/              # 安卓工程（模块 :android）
│   ├── AndroidManifest.xml        # 文件关联 intent-filter
│   └── java/…/md_opener/app/
│       ├── MainActivity.kt        # 入口，处理 VIEW/SEND Intent
│       ├── MainViewModel.kt
│       ├── core/                  # JsBridge / Store / UriHelpers / SiblingResolver
│       └── ui/                    # AppRoot / Home / Viewer / Settings / 组件 / 主题
├── web/                           # ★ 渲染资产（安卓打包为 assets，iOS 打包为 bundle 资源）
│   ├── viewer.html                # 渲染模板（含 callout 等 marked 扩展，运行时探测 Android/iOS 桥）
│   ├── marked.min.js
│   ├── highlight.min.js
│   ├── typewriter.css             # 正文排版
│   ├── hljs-github.css            # 代码高亮（浅色）
│   └── hljs-github-dark.css       # 代码高亮（深色）
├── ios/                           # iOS 工程（XcodeGen：project.yml 为源，xcodeproj 生成物不入库）
│   └── MDOpener/
│       ├── MDOpenerApp.swift      # 入口、onOpenURL
│       ├── Screens/               # Home / Viewer / Settings
│       └── Core/                  # WebView 封装 / 编码检测 / mdres:// 图片解析 / PDF 导出
├── docs/                          # 官网（GitHub Pages 静态站）
├── plans/                         # 开发计划与施工日志
└── tools/                         # keygen 等工具
```

## 构建

> 项目已配置国内镜像（Gradle 走腾讯云、Maven 走阿里云），国内网络可直接同步。
> 合并到 main 后 GitHub Actions 会自动构建，使用固定发布密钥签名，产物可直接覆盖安装。
> 没有本地构建环境（无 Mac / 无 SDK）也能参与开发，方法见 [DEVELOPMENT.md](DEVELOPMENT.md)。

```bash
./gradlew assembleRelease
```

产物路径：`android/build/outputs/apk/release/android-release.apk`

要求：JDK 17+、Android SDK 34。

> 官网「下载 APK」按钮直链指向 `releases/latest/download/MD-Opener-latest.apk`，始终落到最新 Release。发布 Release 时 CI 会自动附上 `MD-Opener-<tag>.apk` 与 `MD-Opener-latest.apk` 两个资产，只需写好说明点发布；旧 Release 里的同名资产无需删除。

## 版本

当前版本 **1.2.3**（versionCode 11）。

## License

MIT
