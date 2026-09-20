# 无 Mac、无本地 SDK 的开发工作法

> **写给谁**：手上只有 Windows / Linux 电脑，没有 Mac，也没装 Xcode / Android SDK，但会用 Git 和 GitHub，并且有一个 AI 编程助手（ZCode / Claude Code / Cursor 等任一）的人。
>
> **两种用法**：
> 1. 自己通读一遍，理解整个闭环怎么转（约 10 分钟）；
> 2. 把 **第 6 节** 整段复制给你的 AI 当工作约定——之后它就知道这套流程里自己该干什么、不该干什么。
>
> 来源：MD Opener 的安卓版和 iOS 版都是用这套方法开发的——本机始终没装 Android SDK，Mac 硬盘也
> 装不下 Xcode（约 40GB）；两个版本全部以纯文本编辑代码，编译验证一律交给 GitHub Actions，最终
> 分别交付签名 APK 与无签名 IPA（侧载前重签）。

---

## 1. 核心思想：把「编译」外包给 GitHub

三个事实凑成一套完整做法：

1. **代码就是文本**。改 Swift / Kotlin / HTML 文件用任何编辑器（或 AI）都行，不需要 IDE，也不需要 SDK。
2. **Xcode 工程也能是文本**。本仓库用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 把工程定义写成 `ios/project.yml`；`.xcodeproj` 不入库，CI 上现场生成。这是「没有 Mac 也能维护 iOS 工程」的关键——你永远不需要打开 Xcode。
3. **GitHub Actions 白送一台 Mac**。公开仓库用标准 macOS runner **完全免费、不限总量**，在上面跑 `xcodebuild` 完成编译打包。

于是分工变成三方循环：

| 角色 | 职责 |
|---|---|
| 你的 AI（在你电脑上） | 改代码、提交、推送 |
| GitHub Actions（在云上） | 回答「能不能编译过」，产出安装包 |
| 你的手机 | 回答「好不好用」 |

**AI 改 → CI 编译 → 真机测 → 反馈 → AI 再改**。没有本地构建环境一样能迭代，代价只是每一轮验证要等几分钟。项目不可能一次写完就没 bug，这套循环转得越顺，修得越快。

---

## 2. 本仓库已经搭好的东西

| 文件 / 目录 | 作用 |
|---|---|
| `.github/workflows/build.yml` | 安卓 APK 构建（正式签名，可直接安装） |
| `.github/workflows/build-ios.yml` | iOS IPA 构建（**无签名**，侧载前需重签） |
| `ios/project.yml` | Xcode 工程的文本定义（唯一事实源） |
| `web/` | 安卓 / iOS **共享**的渲染层（viewer.html，两个 App 的内核） |
| `plans/ios-v1.md` | iOS 版的完整计划与施工日志（含版本策略 §3.5） |
| `docs/ci-and-environment-pitfalls.md` | CI 与开发环境的踩坑记录 |
| `docs/file-association-pitfalls.md` | 安卓文件关联的踩坑记录 |

**触发规则**（两个构建 workflow 一致）：

- push 到 `dev` / `main`，**且**改动碰到对应路径——安卓看 `android/**`、`web/**`；iOS 看 `ios/**`、`web/**`。只改文档、官网不会触发任何构建。
- 在 GitHub 上**发布 Release** 时触发，构建完把安装包自动挂到该 Release 上。
- push 触发的构建**只存 Actions artifact，绝不发布到 Release**——发不发版永远是人工决定。

**产物**：安卓 artifact 名 `md-opener-apk`，iOS artifact 名 `md-opener-ipa`，均保留 30 天后自动过期。

**费用**：仓库是公开的，构建免费不限量。唯一红线：**仓库转私有后** macOS 构建按 10 倍费率计费，免费额度（2000 分钟/月）很快烧完——保持公开就永远不用想这件事。

---

## 3. 标准工作循环：从「发现 bug」到「装上新包」

以 iOS 为例（安卓同理，第 6 步换成直接安装 APK）。一轮约 10~15 分钟。

### 第 1 步：把问题记录成 AI 能用的反馈

不要只说「图片打不开」，按这个模板写：

```
【现象】打开 xxx.md 后所有图片显示为裂图图标
【复现】文件 App → 用 MD Opener 打开 → 正文里图片位置全是裂图
【期望】和文档同目录的 images/a.jpg 应该显示出来
【补充】文档和图片的目录结构截图：……
```

现象、复现步骤、期望行为，三样齐了 AI 就能开工；有截图 / 录屏 / 样张文件更好。

### 第 2 步：交给 AI 修

把反馈贴给你的 AI（第一次使用前先把第 6 节的约定贴给它）。它会改代码、提交、push 到 `dev`。

### 第 3 步：等 CI

约 3~6 分钟。注意：push 后只有改动碰到 `ios/` 或 `web/` 才会触发 iOS 构建；如果 AI 只改了文档导致没触发，属正常，不是坏了。

### 第 4 步：确认绿了

见第 4 节的两种查看方式。绿了才有包拿；红了看日志把第一个错误贴回给 AI。

### 第 5 步：下载安装包

从 Actions 运行页下载 `md-opener-ipa`。注意网页下载的是 **zip**，解压出里面的 `MD-Opener-unsigned.ipa` 才是安装包。

### 第 6 步：重签 + 装机

本仓库的 IPA 是无签名的（CI 上没有也不该有你的证书），用你惯用的重签工具（Windows 上如爱思助手的自签功能，或 AltStore / SideStore 等）重签后安装。**每次拿到新 IPA 都要重新签一次**——签名跟着文件走，旧的签名对新文件无效。

装上后复测第 1 步的问题，解决了就进入下一个问题，没解决就把新现象再喂给 AI。

### CI 红了怎么办

打开失败的那次运行 → 点进 `build` 任务看日志 → 从上往下找**第一个**编译错误 → 整段复制给 AI。不要不改代码就反复重推——同样的代码推一百次也是同样的错。

---

## 4. 查看 CI 与下载产物的两种方式

### 方式 A：纯网页（什么都不用装）

1. 打开 `https://github.com/<所有者>/MDOpener/actions`
2. 左侧选 `Build IPA`（或 `Build APK`），点最新一次运行
3. 页面顶部有结论：绿勾 = 成功，红叉 = 失败（点进 `build` 任务看日志）
4. 成功时页面底部 **Artifacts** 区域点 `md-opener-ipa` 下载

### 方式 B：gh 命令行（装了 [GitHub CLI](https://cli.github.com/) 的话更顺手）

```bash
gh run list --limit 5                      # 最近几次构建
gh run watch <run-id> --exit-status        # 实时盯着某次运行，失败时退出码非 0
gh run view <run-id> --json conclusion --jq .conclusion   # 权威结论：success / failure
gh run download <run-id> --name md-opener-ipa --dir ./out # 下载产物（直接解包，无 zip 套层）
```

一个教训：`gh run watch` 接管道（如 `| tail`）会丢掉真实退出码，**别用管道后的 `$?` 判断成败**，以 `gh run view --json conclusion` 为准。

---

## 5. 关于发版（可选阅读）

日常修 bug 用不到发版，artifact 就够了。想给更多人分发时：

- **iOS**：打 `ios-v0.x.y` 标签并发布 Release（勾选 prerelease）→ CI 自动构建并挂上 `MD-Opener-ios-v0.x.y.ipa`。prelease 标记是为了不抢官网 APK 直链依赖的 `releases/latest` 位。
- **安卓**：打 `v0.x.y` 标签发 Release → CI 自动挂 APK（含 `MD-Opener-latest.apk`）。
- 版本号写在 `ios/project.yml` 的 `MARKETING_VERSION` / `android/build.gradle` 的 `versionName`。

> 注意：`docs/ci-and-environment-pitfalls.md` 末尾的「发版流程速查」是 Release 自动挂载**之前**的手动流程，已被上述自动化取代，仅作历史参考。
> 版本策略的长远规划（iOS 成熟后与安卓统一 vX.Y.Z）见 `plans/ios-v1.md` §3.5。

---

## 6. 给你的 AI 的工作约定（复制整段贴给它）

```text
【环境现状——先读懂再动手】
- 我没有 Mac，本机也没有 Xcode / Android SDK。不要尝试本地构建，不要找本地 gradle、
  xcodebuild 或模拟器；你能做的本地验证只有读代码和推理。
- 本仓库唯一的编译验证是 GitHub Actions：.github/workflows/build.yml（安卓）、
  build-ios.yml（iOS）。
- 触发规则：push 到 dev/main 且改动碰到 android/**、web/**（安卓）或 ios/**、web/**（iOS）。
  只改文档不触发构建。
- 交付形态：安卓 APK 已正式签名可直接安装；iOS IPA 无签名，由我侧重签侧载。

【iOS 工程规则】
- 工程由 XcodeGen 从 ios/project.yml 生成；.xcodeproj 不入库，不要创建或修改它。
  改工程配置 = 改 project.yml。
- 新增 Swift 源文件放进 ios/MDOpener/ 对应子目录（Core/ Model/ Screens/），project.yml
  按目录自动收录；只有 Info.plist 字段、版本号、目标系统版本这类工程级设置才需要动
  project.yml 的 info.properties / settings。
- web/viewer.html 是安卓/iOS 共享渲染层，文件内有 IS_IOS 双平台分支；改它必须保持
  安卓分支行为不变，并且改完后安卓构建也会自动回归验证。

【行为基线】
- 功能对齐安卓版；平台差异允许近似实现（例：「自动打开 PDF」在 iOS 用系统分享面板
  近似安卓的跳转阅读器），但必须在汇报中说明差异。

【分支与验证纪律】
- 日常施工在 dev 分支；不 push main、不打 tag、不发 Release、不动 .github/workflows/，
  除非我明确要求。
- 小步提交：Swift 的类型与编译错误只有 CI 能发现，一次改动越多、失败后定位越难。
  一个关注点一次提交。
- push 后主动跟踪构建：gh run list --limit 3 看状态，以 gh run view <id> --json
  conclusion --jq .conclusion 的输出为准（watch 经管道会丢退出码）。
- 构建失败时：从日志顶部找第一个编译错误，分析、修复、再 push；不要不改代码连续重推。
- 构建成功后，告诉我去哪拿包（Actions 运行页 artifact：md-opener-ipa / md-opener-apk）。

【验证与汇报】
- 你无法验证任何运行时行为；一切 UI、交互、崩溃问题以我的真机反馈为准，修完由我复测。
- 任务结束时汇报三件事：改了什么；CI 结果与 run 链接；哪些行为你没法验证、需要我
  重点测什么。
```

---

## 7. 前置条件清单

开始前需要具备：

1. **Git** 与一个 **GitHub 账号**；仓库所有者把你加为协作者（Settings → Collaborators），
   或者你自己 fork 一份。
   - fork 注意：iOS 构建在 fork 里照常能跑（不需要 secrets）；**安卓构建会失败**，
     因为签名密钥的 Secrets 不随 fork 复制——要动安卓代码请回原仓库。
2. （可选但推荐）**gh CLI**，装后 `gh auth login` 一次。
3. 一个 **AI 编程助手** + 第 6 节的约定。
4. 手机侧的**重签安装工具**（已有自签能力则忽略）。

---

## 8. 已知坑速查

详细记录见两份踩坑文档，这里只列高频项：

| 坑 | 一句话解法 |
|---|---|
| push 了但 CI 没跑 | 检查改动是否碰到触发路径（`ios/`、`android/`、`web/`）；纯文档不触发 |
| 构建失败不知道哪错 | 日志从上往下第一个编译错误才是根因，后面的多是连带 |
| 本机推 workflow 文件被拒 | gh 的 OAuth token 缺 `workflow` 权限，`gh auth refresh -s workflow` 修 |
| SSH 22 端口连不上 GitHub | 走 `ssh.github.com:443`，见 `docs/ci-and-environment-pitfalls.md` |
| 网页下载的 artifact 装不了 | 那是 zip，先解压出里面的 `.ipa` / `.apk` |
| 装上新包提示签名冲突 | iOS：新 IPA 要重新重签；安卓：确认装的是 CI 正式签名包 |

---

## 9. 这套方法的边界（什么时候还是得有真 Mac）

诚实地说清楚它换来了什么、失去了什么：

- **能做**：全部业务代码开发、编译验证、安装包交付、真机功能验证的完整迭代闭环。
- **不能做**：
  - 断点调试、Instruments 性能分析——运行时深排障只能靠「加日志 → 复现 → 看输出」；
  - 上架 App Store（需要开发者账号、证书与 Provisioning 签名链）；
  - 模拟器里快速预览 UI——每次视觉改动都得真机走一轮，节奏慢一拍。
- **代价**：每轮迭代多等几分钟 CI。对个人项目这个代价几乎可以忽略，换来的是零本地环境
  维护成本。

---

*创建：2026-09-21，伴随 iOS v0.1.0 交付整理成文。方法本身与仓库无关，任何「本地无环境 + 公开 GitHub 仓库」的项目都可套用。*
