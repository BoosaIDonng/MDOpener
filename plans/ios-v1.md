# MDOpener iOS 版开发计划（v0.1）

> 状态：**已定稿并施工完成**（2026-09-21，五阶段全部通过 CI 门禁；朋友真机实测待用户侧执行）
> 创建：2026-09-21
> 本文档是施工的唯一事实来源：独立施工会话没有历史对话上下文，一切以本文档为准。

---

## 1. 背景与目标

- 用户的朋友使用 iPhone，想用 MD Opener（目前仅安卓）。朋友具备侧载（自签重签）能力，只需我们提供**无签名 IPA 安装包**，其余安装环节由朋友自行处理（TrollStore / AltStore / Sideloadly / 付费开发者账号，具体方式未知，不影响本计划）。
- 因此本项目**不上 App Store、不注册 Apple 开发者账号、不产生任何签名/证书/描述文件**。iOS 交付物 = GitHub Actions 产出的 unsigned IPA。
- 商业化约束因此解除：侧载无审核，卡密/专业版体系未来可直接照搬（但**本期不做**，见不做清单）。
- 同时把现有仓库升级为 monorepo（`android/` + `ios/` + `web/` 三平级目录），渲染核心（viewer.html 等 Web 资产）单一来源、双端共享。

## 2. 环境硬约束（施工前必读）

| 约束 | 事实 | 对施工的影响 |
|---|---|---|
| 本机无 Xcode | 仅 CommandLineTools，无模拟器、无法本地编译 iOS | **所有 iOS 构建验证走 GitHub Actions**；编译错误靠 CI 日志迭代 |
| 本机无 Android SDK | `~/Library/Android/sdk` 不存在 | **所有安卓构建验证同样走 CI**，本地不跑 gradle |
| 仓库公开 | github.com/honlnk/MDOpener | macOS runner 免费不限量 |
| 提交规范 | 前缀 + 中文描述（`feat:` `fix:` `build:` `ui:` `chore:`，见 git log） | 施工遵循同一格式 |
| 分支 | 日常在 `dev`，PR 合并到 `main` | 施工在 `dev` 进行，**不 push、不发 PR，除非用户明说** |

## 3. 已拍板的决策（不含开放选择题）

以下决策已定死，施工方不得自行更改；确有必要推翻时须记录原因进施工日志并在交付汇报中说明。

### 3.1 仓库与结构

| 决策 | 内容 | 理由 |
|---|---|---|
| monorepo | iOS 代码进本仓库 `ios/` 目录，不开新仓库 | viewer.html 是双端共享核心，分仓必然漂移 |
| 目录命名 | `app/` 改名 `android/`；新增 `ios/`、`web/` | 三平级目录对称 |
| 资产迁移 | `app/src/main/assets/*` 整体迁至根目录 `web/`，gradle `sourceSets.main.assets.srcDirs += ['../web']` | 单一来源；安卓 `loadUrl` 路径不变 |
| 双端兼容方式 | viewer.html **运行时探测**（`window.webkit.messageHandlers` 存在即 iOS），不做构建期模板 | 单文件双端，无构建机制负担 |

### 3.2 iOS 工程

| 决策 | 内容 |
|---|---|
| 技术栈 | Swift + SwiftUI，WKWebView 渲染，零第三方依赖（ marked/highlight.js 为 bundled Web 资产，非 SPM 依赖） |
| 工程管理 | **XcodeGen**（`ios/project.yml` 为源，`.xcodeproj` 生成物进 .gitignore，CI 上 `brew install xcodegen && xcodegen generate`）——本机无 Xcode 也能用文本维护工程 |
| 最低部署版本 | iOS 16.0（NavigationStack、`LabeledContent` 等可放心用） |
| Bundle ID | `com.honlnk.mdopener`（与安卓 applicationId 不需要一致） |
| 显示名 | MD Opener（与安卓一致） |
| iOS 版本号 | v0.1.0（build 1）起步，独立演进，不与安卓 1.2.3 锁步 |

### 3.3 功能与交互（对齐安卓版，用户可见行为一致）

| 项 | 拍板值 |
|---|---|
| 入口 | 与安卓三入口对齐其二：文件 App / 第三方「打开方式」拉起（UTI 关联 `net.daringfireball.markdown`）；桌面图标进首页自选文件。**Share Extension 本期不做**（重签兼容风险） |
| 首页形态 | 照搬安卓：大圆按钮选文件，右上角「最近文档」（仅本次运行内存级，退出清空） |
| 默认设置 | 字号 17、正文宽度 720pt、主题跟随系统、PDF A4 / 不保留背景 / 不自动打开——与安卓 Store.kt 默认值完全一致 |
| 设置范围 | 主题（跟随/浅/深）、字号 12–28、宽度 240–1100pt（超屏宽提示同安卓）、PDF 三项 |
| 相对图片授权 | **非阻断**：文档渲染不受影响，未解析图片显示占位；检测到未解析相对图片且无文件夹授权时，查看器顶部显示横幅「本文档包含相对路径图片，授权所在文件夹后可显示」+「去授权」按钮，可忽略、每次打开该文档最多提示一次 |
| TOC / 页内搜索 | 与安卓同：工具栏入口，实时高亮、显示命中数 |
| PDF 导出 | `UIMarkupTextPrintFormatter` 自动分页 + `UIGraphicsPDFRenderer` 落盘；`---` 强制分页经 CSS page-break 生效；导出前自动展开折叠、导出后可选自动打开 |
| 编码检测 | BOM 嗅探 → UTF-8 严格校验 → GB18030 回退（`CFStringEncodings.GB_18030_2000`），逻辑与安卓 UriHelpers.kt 一致 |
| 分级返回 | 外部拉起的文档直接退出回来源 App；应用内导航逐级返回 |

### 3.4 交付与发布

| 决策 | 内容 | 理由 |
|---|---|---|
| IPA 签名 | 无签名（`CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`），朋友侧重签 | 无账号、无成本 |
| 日常产物 | Actions artifact（`md-opener-ipa`，30 天保留），朋友从 Actions 运行页下载 | 不碰 Release，官网零风险 |
| 里程碑产物 | `ios-v0.1.0` 格式 tag + **prerelease 标记**的 Release 挂 IPA | prerelease 不进入 `releases/latest` 计算，官网 APK 直链（`releases/latest/download/MD-Opener-latest.apk`，docs/index.html:311,472,580 依赖）不受影响 |
| 统一发版 | **本期不启用**，终态方向已拍板 → 见 §3.5 | 避免本期改动官网 |

### 3.5 版本策略（终态方向已定，本期不启用）

与用户确认的长期策略：**iOS 成熟后切统一 `vX.Y.Z` 发版——一个 Release 同时挂 APK + IPA，两平台营销版本号锁步**。核心理由：`web/` 渲染核心共享，两平台发布天然耦合，统一后渲染层修复一次发版两边同时拿到，且官网 `releases/latest` 直链体系对双平台永远成立。

| 阶段 | tag 形态 | 说明 |
|---|---|---|
| 现在（iOS 测试期） | `v1.2.x` 安卓正式版 + `ios-v0.x` prerelease | 互不干扰，官网零风险 |
| 切换点 | 最后一个 `ios-v0.x` 发完即止 | 切换条件见下 |
| 长期终态 | 统一 `vX.Y.Z`，双资产同发 | 一次发版两边同版本 |

**切换条件（全部满足才切）**：iOS 功能对齐 §3.3 功能表；PDF 导出稳定；朋友连续日常使用约两周无阻断性问题。

**切换后运作规则**：
- 版本号衔接：不回溯追号。切换时安卓在哪个版本（如 1.5.x），首个统一版顺延命名（1.6.0），iOS 侧 MARKETING_VERSION 对齐该值
- 安卓 versionCode 与 iOS build 号（CFBundleVersion）继续各自独立递增，仅营销版本号（versionName / MARKETING_VERSION）锁步
- 单平台热修也走统一 tag 重发：未改动的一侧「同代码 + 版本号 +1」重新出包；**不开某一边单独发正式版的口子**——那会重新弄断官网 `releases/latest` 链
- 历史 `ios-v0.x` Release 全部保持 prerelease 留档，不清理、不进 latest 链
- 切换时需同步做的事（属新计划，不在本期内）：官网加 iOS 下载入口（`releases/latest/download/MD-Opener-ios-latest.ipa`）、确认版本号 API 语义、README 发版说明更新

## 4. 明确不做清单（本期诱惑项排除）

1. **Share Extension**（ACTION_SEND 等价物）——App Group 重签兼容风险，本期砍
2. **卡密 / 专业版体系**——侧载无审核本可照搬，但 v0.1 先给朋友能用，商业化后置
3. **检查更新**——侧载场景无意义
4. **App Store / TestFlight / 国内商店上架**——已明确走侧载
5. **iPad 专门布局、横屏专门优化**——SwiftUI 默认自适应即可，不做专门设计
6. **小组件、iCloud、本地化多语言**——界面文案中文（系统控件语言跟随系统）
7. **XCU 测试 target**——v0.1 验证 = CI 构建 + 用户真机/朋友实测（见 §8 降级验证），测试框架后置
8. **安卓业务代码改动**——阶段①仅动结构与构建配置，不动业务逻辑
9. **官网（docs/）改动**——不加 iOS 下载入口、不改版本号逻辑

## 5. 目标结构

```
MDOpener/
├── android/                   # 原 app/（业务代码不动，仅迁移）
│   └── build.gradle           # + sourceSets 指向 ../web
├── ios/
│   ├── project.yml            # XcodeGen 工程定义（源文件，进 git）
│   ├── .gitignore             # 屏蔽生成物
│   └── MDOpener/
│       ├── MDOpenerApp.swift        # 入口、onOpenURL
│       ├── AppRoot.swift            # 导航根
│       ├── Screens/
│       │   ├── HomeScreen.swift
│       │   ├── ViewerScreen.swift
│       │   └── SettingsScreen.swift
│       ├── Core/
│       │   ├── MarkdownWebView.swift     # WKWebView 封装、JS 注入
│       │   ├── DocumentLoader.swift      # 读取 + 编码检测
│       │   ├── ImageSchemeHandler.swift  # mdres:// 拦截
│       │   ├── PdfExporter.swift
│       │   └── SettingsStore.swift       # UserDefaults
│       └── Model/Models.swift
├── web/                       # 原 app/src/main/assets/（渲染资产唯一来源）
├── docs/  tools/              # 不动
└── .github/workflows/
    ├── build.yml              # 安卓：改名路径 + workflow_dispatch + paths 过滤
    ├── build-ios.yml          # 新增
    └── deploy-pages.yml       # + docs/** paths 过滤
```

## 6. 阶段分解（每阶段一事，门禁不过不开下一阶段）

### 阶段 ① 结构调整（monorepo 化）

**任务**
1. `git mv app android`；`settings.gradle`：`include ':app'` → `include ':android'`
2. `git mv android/src/main/assets web`；`android/build.gradle` 加 `sourceSets { main { assets.srcDirs += ['../web'] } }`
3. `build.yml`：`app/build/outputs/apk/release` → `android/build/outputs/apk/release`（两处）；`cp app-release.apk` → `cp android-release.apk`（模块改名导致产物文件名变化，两处）；增加 `workflow_dispatch`（dev 分支可手动触发验证）；增加 `paths: [android/**, web/**]` 过滤
4. `deploy-pages.yml` 加 `paths: [docs/**]`
5. 根 `.gitignore` 增加 `ios/` 生成物条目（xcuserdata、DerivedData、.xcodeproj）
6. README 项目结构一节同步更新

**验收（全部可执行）**
- CI：dev 分支手动触发 build workflow，`assembleRelease` 成功（debug 签名回退，符合预期）
- 产物存在且为合法 APK：artifact `md-opener-apk` 下载可解包
- `web/` 与原 `app/src/main/assets/` 内容一致（`diff` 为空）
- git log 显示 rename 而非删除新增（`git log --follow` 可追历史）

**门禁**：CI 绿 + README 更新 + 施工日志追加。**本阶段不创建任何 iOS 文件。**

### 阶段 ② iOS 骨架（工程 + 壳 + WebView 桥）

**任务**
1. `ios/project.yml`（XcodeGen）：target MDOpener，iOS 16.0，bundle id `com.honlnk.mdopener`，Resources 指向 `../web`（folder reference），Info.plist 声明 `CFBundleDocumentTypes` + UTI 关联（.md/.markdown/.mdown，含 UTImportedTypeDeclarations 兜底）
2. viewer.html 双端探测改造：`IS_IOS` 常量；TOC 上报双分支（`AndroidBridge.reportToc` / `webkit.messageHandlers.toc.postMessage`）；`onReady` 同理；相对图片 iOS 分支改写 `src` 为 `mdres://`；安卓分支行为**零变化**
3. Swift 侧：MDOpenerApp / AppRoot / HomeScreen（大圆按钮 + UIDocumentPicker 选 .md）/ ViewerScreen 骨架 / MarkdownWebView（WKWebView、loadFileURL 加载 bundle 内 viewer.html、`setMarkdown`/`applyTheme` 注入、toc 消息接收）/ DocumentLoader（纯 UTF-8 路径先行）/ Models
4. `build-ios.yml`（按 §3.4；runs-on 固定 macos 镜像版本，Xcode 版本以 runner 实际支持为准并在 workflow 注释里写死，拒绝 latest）

**验收**
- CI：`build-ios.yml` 在 dev 分支手动触发成功，产出 `MD-Opener-unsigned.ipa`（Payload/MDOpener.app 结构完整，`unzip -l` 可验）
- 安卓回归：viewer.html 改动后 build workflow 再跑一次仍绿（双端探测不破坏安卓）
- 模拟器 UI：**降级验证**——本机无 Xcode，模拟器效果由用户事后自行验证（或直接跳到朋友真机），CI 无法验 UI

**门禁**：双 workflow 绿 + 日志。

### 阶段 ③ 文件链路（打开方式 + 编码）

**任务**
1. `onOpenURL` / Scene 处理外部拉起（`.md` UTI）；分级返回语义（外部拉起单实例直接退出）
2. DocumentLoader 补全编码检测：BOM 嗅探 → `String(contentsOf:encoding:.utf8)` 严格失败 → GB18030（`CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))`）
3. 最近文档（内存级，会话内有效）

**验收**
- CI 构建绿
- 功能验证降级：用户/朋友真机——文件 App 打开 .md 能拉起 App 并渲染；GBK 编码样张不乱码；准备 `test/fixtures/gbk-sample.md`（GB18030 编码测试文件）进仓库供验证

### 阶段 ④ 功能补齐（设置 / TOC / 搜索 / 图片）

**任务**
1. SettingsScreen + SettingsStore（UserDefaults，键名与默认值对齐 §3.3 表）
2. TOC 抽取展示与跳转（`scrollToHeading` 注入）
3. 页内搜索（`findText` 注入 + 命中数显示）
4. ImageSchemeHandler（`mdres://` 注册 + 拦截）：相对路径 → 同目录解析；安全作用域：file URL 直选的单文件无邻访权，检测到未解析相对图片时按 §3.3 横幅方案引导文件夹授权（`UIDocumentPickerViewController(forOpeningContentTypes: [.folder])` + security-scoped bookmark 持久化）
5. 主题/字号/宽度全链路（applyTheme 注入，pt 与安卓 dp 等值处理）

**验收**
- CI 构建绿
- 真机功能核对由用户执行，核对单在本阶段施工时生成进施工日志（项：TOC 跳转、搜索高亮计数、深色模式、字号宽度即时生效、相对图片授权前占位/授权后显示）

**门禁**：CI 绿 + 核对单写入日志。

### 阶段 ⑤ 导出与交付

**任务**
1. PdfExporter：`UIMarkupTextPrintFormatter`（取渲染后 HTML）+ `UIGraphicsPDFRenderer`（纸张 A4/A5/B5/Letter/Legal、页边距、可选整页背景）；导出前 `preparePrint` 注入展开折叠，导出后 `restoreAfterPrint`
2. `---` 强制分页：打印专用 CSS（`page-break-after`）注入，仅打印态生效
3. 交付演练：打 `ios-v0.1.0` tag 发 prerelease Release，workflow 上传 `MD-Opener-ios-<tag>.ipa`；朋友真机安装走通并反馈
4. 发版前确认官网不受影响：`releases/latest` API 返回仍为安卓最新正式版

**验收**
- CI 绿 + Release 资产存在且为 prerelease
- 朋友真机：安装成功、日常打开 .md 可用（用户口头确认即可，截图留档进日志更好）
- 官网下载按钮直链可达（curl -I 200）

**门禁**：全部通过后本计划状态改「已完成」。

## 7. 迁移与兼容条款

| 改动 | 旧的去向 | 用户影响 |
|---|---|---|
| `app/` → `android/` | 旧目录消失（git rename） | 无。applicationId / 签名 / 版本号全不变 |
| APK 产物名 `app-release.apk` → `android-release.apk` | CI 内部文件名 | 无。Release 资产仍为 `MD-Opener-<tag>.apk` / `MD-Opener-latest.apk`，官网直链不变 |
| `assets/` → `web/` | 旧目录消失（git rename），gradle 改指向 | 无。`file:///android_asset/viewer.html` 加载路径不变 |
| viewer.html 双端改造 | 安卓分支保持原逻辑 | 安卓行为零变化（阶段②验收含安卓回归） |
| 无旧用户数据 / 配置 / 服务端状态需要迁移 | — | — |

## 8. 新旧机制替代表

| 旧机制 | 新机制 | 关系 |
|---|---|---|
| `build.yml`（唯一构建） | `build.yml`（安卓，过滤）+ `build-ios.yml`（iOS） | 并存，各管各的目录 |
| viewer.html 仅安卓桥 | 运行时探测双端桥 | 替换（安卓走原 `AndroidBridge` 分支不变） |
| 相对图片：`AndroidBridge.resolveImage` 同步桥 | iOS：`mdres://` scheme 异步拦截 | 双端各自实现，viewer.html 内分流 |
| 无 iOS 工程 | `ios/project.yml`（XcodeGen 文本源） | 新增；`.xcodeproj` 为生成物不入库 |

## 9. 验收与降级验证总说明

- **自动化验证 = CI 构建成功**（两平台 workflow 均支持 workflow_dispatch，dev 分支可直接触发，不污染 main）。
- **本机无 Xcode/Android SDK**：一切本地编译、模拟器、单测均不可用，属环境既定事实而非偷懒。
- UI / 真机体验验证降级为用户人工：每阶段的「真机核对单」随施工写入日志，用户按单复核。
- 朋友重签安装是最终验收的一环；若朋友 7 天签名过期属预期现象（免费 Apple ID 侧载机制），不算缺陷。

## 10. 文档同步计划

- **本文档**（`plans/ios-v1.md`）随施工随手更新：§11 状态表流转、§12 施工日志追加（格式：`日期 | 阶段 | 提交 hash | 验收结论 | 偏差记录`）。
- **README.md**：阶段①完成时更新项目结构；iOS 交付说明（侧载指引）在阶段⑤完成后补。
- 偏差当场记录：方案被推翻时必须写明原方案为何不行、新方案好在哪。

## 11. 阶段状态总览

| 阶段 | 内容 | 状态 |
|---|---|---|
| ① | 结构调整（monorepo 化） | ✅ 已完成（CI 35524316945 绿） |
| ② | iOS 骨架（工程 + 壳 + WebView 桥） | ✅ 已完成（CI 35524805764 绿，IPA 126KB；安卓回归 35524618646 绿） |
| ③ | 文件链路（打开方式 + 编码） | ✅ 已完成（编码/外部拉起/最近文档随②实现；GBK 样张 + 本机解码实测通过） |
| ④ | 功能补齐（设置 / TOC / 搜索 / 图片） | ✅ 已完成（CI 35525066347 绿；安卓回归 35525066310 绿） |
| ⑤ | 导出与交付（PDF + IPA + 朋友实测） | ✅ 代码与交付链路完成（CI 35525319184 绿；`ios-v0.1.0` prerelease 已发）；朋友真机实测待用户侧执行 |

## 12. 施工日志
- 2026-09-21 | 阶段① | `8faee36` | CI run 35524316945 success，artifact `md-opener-apk`（1.2MB）存在；`web/` 六个文件与原 assets git rename 相似度 100%，历史可 `--follow` 追溯 | 偏差 4 条：① `workflow_dispatch` 要求 workflow 文件先存在于默认分支，dev 施工期不可用 → 改为 build.yml 的 push 触发加入 dev 分支（顺带成为长期有用的验证通道）；② deploy-pages.yml 实为 tag 触发（v*/site-*），计划中「加 paths 过滤」不适用，跳过；③ 计划未预见 build.yml 的 release 触发无 tag 过滤，发 ios-v* 时会把 APK 错误挂上 iOS Release → 已补 `!startsWith(tag, 'ios-')` 跳过条件；④ 未单独创建 ios/.gitignore，根 .gitignore 的 iOS 条目已覆盖同一目的。
- 2026-09-21 | 阶段② | `12c7213` + `78bc85c` | 首跑 35524618698 编译失败（可选元组不遵循 Equatable，MarkdownWebView.swift:94），拆字段判等修复后 35524805764 success；IPA 含 `Payload/MDOpener.app/web/`（folder reference 生效，viewer 相对引用可用）；viewer.html 改动后安卓回归 35524618646 绿 | 偏差 2 条：① 编码检测（DocumentLoader）提前并入②实现，③仅剩样张与验证——理由：代码独立且一次写好无拆分收益；② Info 补 `LSSupportsOpeningDocumentsInPlace: true`（构建警告 + 原地打开保留文件名，优于默认 tmp Inbox 拷贝）。
- 2026-09-21 | 阶段③ | 随②提交 | GBK 样张 `test/fixtures/gbk-sample.md`（GB18030 实编码）入库；DocumentLoader 与 macOS 测试壳本机编译直跑：GB18030 / UTF-8 / BOM 三链路断言全过 | 无。真机「打开方式」拉起与最近文档体验留待用户复核（本机无 Xcode/模拟器，属计划内降级验证）。
- 2026-09-21 | 阶段④ | `71627d8` | CI 35525066347 一次通过；viewer.html 改动后安卓回归 35525066310 绿 | 无。
  - **真机核对单（用户侧执行）**：① 文件 App 长按 .md →「打开方式」→ MD Opener 能拉起并渲染；② 目录点击后正文滚动到位；③ 搜索实时高亮、计数正确、清除后高亮消失；④ 设置切深色后正文与外壳同步换色，字号/宽度即时生效；⑤ 相对图片：未授权时占位 + 横幅（每文档仅一次），「去授权」选文件夹后图片显示；⑥ GBK 样张（`test/fixtures/gbk-sample.md` 放入手机）打开不乱码。
- 2026-09-21 | 阶段⑤ | `fd84261` + `5fc3f73` + tag `ios-v0.1.0` | CI 35525319184 一次通过；prerelease Release 已发（run 35525500948 success），资产 `MD-Opener-ios-v0.1.0.ipa`（228KB）；`releases/latest` 仍为安卓 v1.2.3 非预发布，官网 APK 直链 HTTP 200——官网零影响验收通过 | 偏差 2 条：① release 资产名原会拼成 `MD-Opener-ios-ios-v0.1.0.ipa`（TAG 自带前缀重复），已改为剥离 `ios-` 前缀再拼名；② 「自动打开」在 iOS 上实现为保存成功后弹系统分享面板（快速预览/存储/转发），与安卓「跳转 PDF 阅读器」语义近似而非逐字对齐。`---` 强制分页依赖打印 CSS（hr+* break-before），UIMarkupTextPrintFormatter 对该 CSS 的支持度属真机验证项。



## 13. 风险与预案

| 风险 | 预案 |
|---|---|
| runner Xcode 版本漂移导致构建突然红 | 镜像与 Xcode 版本在 workflow 中写死并注释，升级是显式提交 |
| WKWebView 与 Chromium 渲染差异（打印分页 CSS、字体度量） | 阶段⑤真机实测调整；正文渲染差异容忍（两平台字体栈本就不同） |
| 重签工具对 Info.plist 权限/UTI 的兼容性 | 阶段②交付第一个 IPA 后即请朋友试装「打开方式」是否生效，早暴露 |
| `mdres://` 在重签后失效 | scheme handler 是 WKWebView 层注册，与签名无关，理论无风险；列入真机核对单 |
| 朋友为 7 天签名（免费 Apple ID） | 预期管理：交付时说明续签机制，不算缺陷 |
| monorepo 改名破坏外部脚本/书签 | 已排查：官网与 README 引用的都是 Release 资产名与仓库级 URL，无模块路径引用 |
