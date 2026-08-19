# FF Converter · 视频格式转换大师

> 本地、免费、带硬件加速的 Windows 视频转换器。拖进去，点一下，搞定。

[![Windows](https://img.shields.io/badge/platform-Windows-0078D6?logo=windows&logoColor=white)](https://github.com/zxcvbnm555666/ffconverter)
[![Flutter](https://img.shields.io/badge/Flutter-Desktop-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FFmpeg](https://img.shields.io/badge/powered%20by-FFmpeg-007808)](https://ffmpeg.org)
[![License](https://img.shields.io/badge/license-使用请遵守-lightgrey)](#)

---

## 为什么值得下载

网上一堆「转格式」工具，不是捆绑软件，就是上传到云端、限速、加水印。  
**FF Converter** 把 FFmpeg 的能力做成真正能用的桌面应用：

| 痛点 | 我们怎么解决 |
|------|----------------|
| 转换慢 | 自动检测 **NVIDIA / Intel / AMD** 硬件编码，能硬解就硬解 |
| 格式对不上 | 一键输出 MP4 / MKV / MOV / WebM / FLV … 覆盖日常场景 |
| 参数太难 | 「质量」或「码率」二选一，分辨率、帧率滑一下就行 |
| 不放心隐私 | **全程本地转换**，视频不会上传任何服务器 |
| 界面难看 | 水墨国风深色界面，无边框窗口，用起来干脆 |

装好就能用，内置 FFmpeg，不用自己配环境。

---

## 核心能力

- **拖放即转** — 把视频拖进窗口，或点「选择文件」
- **双模式** — 快速转换（改封装）/ 重新编码（改画质与体积）
- **硬件加速** — CUDA（NVIDIA）、QSV（Intel）、AMF（AMD），启动时自动探测
- **编码任选** — H.264 / H.265 / AV1 / VP9 等
- **音视频可控** — 质量 ↔ 码率互斥、分辨率、帧率、音频码率
- **进度可见** — 实时进度、速度；调试面板可看完整 FFmpeg 命令与日志
- **开箱即用** — `windows/runner/ffmpeg.exe` 已随项目附带

---

## 界面一览

左侧选源文件与开始转换，右侧调目标格式与编码参数；顶部可设输出目录、最小化 / 最大化 / 关闭。

适合：剪辑师补格式、UP 主压体积、普通用户换 MP4 发给微信/抖音。

---

## 快速开始

### 方式一：直接运行（已编译）

若你已有 Release 构建产物：

```text
ffconverter/build/windows/x64/runner/Release/ffconverter.exe
```

双击即可（请保证同目录下 FFmpeg 相关文件完整）。

### 方式二：从源码编译

环境要求：

- Windows 10/11
- [Flutter](https://docs.flutter.dev/get-started/install/windows)（支持 Desktop）
- Visual Studio（含「使用 C++ 的桌面开发」）

```bash
git clone https://github.com/zxcvbnm555666/ffconverter.git
cd ffconverter/ffconverter
flutter pub get
flutter run -d windows
# 或发布版：
flutter build windows
```

产物路径：

```text
build/windows/x64/runner/Release/ffconverter.exe
```

---

## 项目结构

```text
ffvideotrans/
└── ffconverter/                 # Flutter 应用
    ├── lib/
    │   ├── main.dart            # 主界面与窗口控制
    │   ├── models/settings.dart # 格式 / 编码 / FFmpeg 参数
    │   ├── ffmpeg/              # 探测、转码、缩略图
    │   └── widgets/             # 源文件卡、设置卡
    ├── windows/runner/          # 无边框窗口 + 内置 ffmpeg.exe
    └── assets/images/           # 水墨背景与图标
```

---

## 技术栈

- **Flutter Desktop** — Windows UI
- **FFmpeg** — 转码引擎（已内置）
- **Win32** — 无边框窗口、拖动与最大化

---

## 路线图（欢迎 Star 催更）

- [ ] 批量队列转换
- [ ] 更多预设（抖音竖屏、B 站上传、微信小视频）
- [ ] 安装包 / 便携版一键分发
- [ ] 深浅色与更多主题

觉得好用的话，点个 **Star**，比请咖啡更实在。

---

## 说明与致谢

- 转码能力来自 [FFmpeg](https://ffmpeg.org/)，请遵循其许可证与专利相关规定。
- 本项目仅供学习与个人使用；请勿用于侵犯版权的内容。

---

**下载、Star、反馈 Issue —— 你的一次点击，就是下一次更新的动力。**

仓库：https://github.com/zxcvbnm555666/ffconverter
