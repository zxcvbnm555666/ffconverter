import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'ffmpeg/ffmpeg_runner.dart';
import 'models/settings.dart';
import 'widgets/source_card.dart';
import 'widgets/settings_card.dart';
import 'widgets/common.dart';
import 'window_controller.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '视频格式转换大师',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: AppColors.fontFamily,
          scaffoldBackgroundColor: const Color(0xFFE8E4DC),
          useMaterial3: true,
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final settings = ConvertSettings();
  Set<EncoderHw> _hwEncoders = const {EncoderHw.software};
  String? _outputDir;
  bool _busy = false;
  double _progress = 0;
  String _speed = '';
  String? _inputPath;
  String? _lastOutput;
  String _status = '';
  // 调试信息（用 ValueNotifier 以便弹窗实时刷新）
  final ValueNotifier<String> _lastCommand = ValueNotifier('');
  final ValueNotifier<String> _logText = ValueNotifier('');
  bool _stopRequested = false;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _detectHw();
    _syncMaxState();
  }

  Future<void> _syncMaxState() async {
    final m = await WindowController.isMaximized();
    if (mounted) setState(() => _isMaximized = m);
  }

  /// 切换窗口最大化/还原（原生端自动判断当前状态）。
  Future<void> _toggleMaximize() async {
    await WindowController.maximize();
    final m = await WindowController.isMaximized();
    if (mounted) setState(() => _isMaximized = m);
  }

  Future<void> _detectHw() async {
    try {
      final available = await FFmpegRunner.instance.detectHwAccel();
      if (mounted) {
        setState(() {
          _hwEncoders = available;
          // 默认优先使用硬件编码：检测到硬件方案且当前仍是软件时，选第一个硬件方案
          final hwList = available.where((e) => e != EncoderHw.software).toList();
          if (hwList.isNotEmpty) {
            if (settings.encoderHw == EncoderHw.software) {
              settings.encoderHw = hwList.first;
            }
          } else {
            settings.encoderHw = EncoderHw.software;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickOutputDir() async {
    final res = await FilePicker.platform.getDirectoryPath();
    if (res != null) setState(() => _outputDir = res);
  }

  /// 预检输入输出，给出具体提示而非交给 ffmpeg 模糊报错。
  String? _preflight(String input, String output) {
    final inp = File(input);
    if (!inp.existsSync()) return '输入文件不存在：$input';
    try {
      inp.lengthSync();
    } catch (e) {
      return '无法读取输入文件：$e';
    }
    final outFile = File(output);
    final outDir = outFile.parent;
    if (!outDir.existsSync()) {
      try {
        outDir.createSync(recursive: true);
      } catch (e) {
        return '输出目录不存在且无法创建：${outDir.path}\n$e';
      }
    }
    // 写入权限测试
    try {
      final probe = File('${output}.probe');
      probe.writeAsStringSync('test');
      probe.deleteSync();
    } catch (e) {
      return '输出目录无写入权限：${outDir.path}\n$e';
    }
    return null;
  }

  Future<void> _startConvert() async {
    if (_inputPath == null) {
      setState(() => _status = '请先选择源视频文件');
      return;
    }
    if (_busy) return;
    _stopRequested = false;
    setState(() {
      _busy = true; _progress = 0; _speed = ''; _status = '准备中…';
    });
    _lastCommand.value = '';
    _logText.value = '';
    try {
      final out = settings.defaultOutput(_inputPath!, _outputDir);
      final preErr = _preflight(_inputPath!, out);
      if (preErr != null) {
        if (mounted) setState(() => _status = preErr);
        return;
      }
      final info = await FFmpegRunner.instance.probe(_inputPath!);
      var args = settings.buildArgs();
      var result = await _runConvert(out, args, info.duration);

      // 硬件编码失败时自动回退到软件编码重试一次
      if (result != null && !result.success && settings.encoderHw != EncoderHw.software) {
        final logText = result.logTail.join('\n').toLowerCase();
        final hwFailed = logText.contains('nvenc') || logText.contains('amf') || logText.contains('qsv') ||
            logText.contains('cuda') || logText.contains('hwaccel') || logText.contains('cannot open') ||
            logText.contains('failed to init') || logText.contains('error while opening encoder');
        if (hwFailed) {
          // 取首次失败时的关键错误行（最多 2 条）给用户看
          String reason = '';
          for (final l in result.logTail.reversed) {
            final tl = l.trim();
            if (tl.isEmpty) continue;
            if (RegExp(r'(error|failed|invalid|cannot|no nv|nvml)', caseSensitive: false).hasMatch(tl)) {
              reason = reason.isEmpty ? tl : '$tl\n$reason';
              if (reason.split('\n').length >= 2) break;
            }
          }
          if (mounted) setState(() => _status = reason.isEmpty
              ? '硬件加速不可用，已自动回退到软件编码…'
              : '硬件加速不可用：\n$reason\n已自动回退到软件编码…');
          settings.encoderHw = EncoderHw.software;
          args = settings.buildArgs();
          result = await _runConvert(out, args, info.duration);
        }
      }

      if (mounted) {
        if (_stopRequested || result == null) {
          setState(() => _status = '转换已停止');
        } else {
          final r = result; // 此时已确保非空
          if (r.success) {
            setState(() { _status = '转换完成：$out'; _lastOutput = out; });
          } else {
            setState(() => _status = '转换失败：\n${r.errorMessage}');
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _status = '错误：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 停止当前转换进程。
  void _stopConvert() {
    _stopRequested = true;
    FFmpegRunner.instance.stop();
    if (mounted) setState(() => _status = '正在停止…');
  }

  Future<FFmpegResult?> _runConvert(String out, List<String> args, Duration? duration) async {
    return FFmpegRunner.instance.convert(
      input: _inputPath!,
      output: out,
      args: args,
      preInputArgs: settings.hwaccelInputArgs(),
      totalDuration: duration,
      onProgress: (p, sp) {
        if (mounted) setState(() { _progress = p; _speed = sp; });
      },
      onCommand: (c) => _lastCommand.value = c,
      onLog: (line) {
        final cur = _logText.value;
        final updated = cur.isEmpty ? line : '$cur\n$line';
        // 限制行数，避免无限增长
        final parts = updated.split('\n');
        if (parts.length > 600) parts.removeRange(0, parts.length - 600);
        _logText.value = parts.join('\n');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 水墨背景
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage('assets/images/bg_ink.png'), fit: BoxFit.cover),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) => WindowController.startDrag(),
            onDoubleTap: _toggleMaximize,
            child: Column(
              children: [
                _buildTitleBar(),
                Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左侧：源文件卡片 + 状态栏
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SourceCard(
                            settings: settings,
                            outputDir: _outputDir,
                            busy: _busy,
                            progress: _progress,
                            speed: _speed,
                            onConvert: _startConvert,
                            onStop: _stopConvert,
                            onInputChanged: (p) => setState(() => _inputPath = p),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(width: 540, child: _buildStatusPanel()),
                        ],
                      ),
                      const SizedBox(width: 40),
                      // 右侧：目标设置
                      SettingsCard(
                        settings: settings,
                        hwEncoders: _hwEncoders,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        ],
      ),
    );
  }

  /// 弹出调试信息对话框：实时显示命令行与 ffmpeg 输出。
  Future<void> _openDebugPanel() async {
    final _logScroll = ScrollController();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 860,
          constraints: const BoxConstraints(maxHeight: 640),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.terminal, size: 16, color: AppColors.primaryRed),
                  const SizedBox(width: 6),
                  const Text('调试信息', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: AppColors.fontFamily)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _logText.value = '',
                    icon: const Icon(Icons.delete_sweep, size: 15, color: AppColors.textSecondary),
                    label: const Text('清空', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: AppColors.fontFamily)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                    tooltip: '关闭',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 命令行
              const Text('命令行：', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: AppColors.fontFamily)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.innerBg, borderRadius: BorderRadius.circular(6)),
                child: ValueListenableBuilder<String>(
                  valueListenable: _lastCommand,
                  builder: (_, cmd, __) => SelectableText(
                    cmd.isEmpty ? '（尚未执行转换）' : cmd,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CDCFE), fontFamily: 'Consolas', height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('ffmpeg 实时输出：', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: AppColors.fontFamily)),
              const SizedBox(height: 4),
              Container(
                height: 320,
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.innerBg, borderRadius: BorderRadius.circular(6)),
                child: ValueListenableBuilder<String>(
                  valueListenable: _logText,
                  builder: (_, text, __) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_logScroll.hasClients) {
                        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
                      }
                    });
                    return Scrollbar(
                      controller: _logScroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _logScroll,
                        child: SelectableText(
                          text.isEmpty ? '（暂无输出）' : text,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFB8B8B8), fontFamily: 'Consolas', height: 1.4),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 无系统标题栏：贴顶操作条（可拖动）+ 输出路径 + 最小/最大化/关闭。
  Widget _buildTitleBar() {
    return Material(
      color: const Color(0xF0161618),
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
        ),
        child: Row(
          children: [
            // 拖动区（双击切换最大化）
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open, size: 16, color: AppColors.primaryRed),
                    const SizedBox(width: 8),
                    const Text('输出目录：', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: AppColors.fontFamily)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _outputDir ?? '默认与源文件同目录',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: _outputDir != null ? AppColors.textPrimary : AppColors.textMuted,
                          fontFamily: AppColors.fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ActionButton(text: '输出目录', icon: Icons.folder_open, onPressed: _pickOutputDir),
            const SizedBox(width: 8),
            ActionButton(
              text: _lastOutput != null ? '打开结果' : '队列',
              icon: _lastOutput != null ? Icons.open_in_new : Icons.playlist_add,
              onPressed: _lastOutput != null ? () => _openFile(_lastOutput!) : () {},
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: '查看命令行与 ffmpeg 实时输出',
              child: ActionButton(
                text: '调试信息',
                icon: Icons.bug_report,
                onPressed: _openDebugPanel,
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 20, color: AppColors.borderColor),
            const SizedBox(width: 2),
            _WinButton(icon: Icons.remove, onTap: () => WindowController.minimize(), tooltip: '最小化'),
            _WinButton(
              icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
              onTap: _toggleMaximize,
              tooltip: _isMaximized ? '还原' : '最大化',
            ),
            _WinButton(icon: Icons.close, onTap: () => WindowController.close(), tooltip: '关闭', danger: true),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// 状态面板：显示当前状态、进度条、错误日志。
  Widget _buildStatusPanel() {
    final ok = _status.startsWith('转换完成');
    final fail = _status.startsWith('转换失败') || _status.startsWith('错误');
    Color borderColor = AppColors.cardBorder;
    Color textColor = AppColors.textSecondary;
    IconData icon = Icons.info_outline;
    if (ok) {
      borderColor = const Color(0xFF2E7D32);
      textColor = const Color(0xFF81C784);
      icon = Icons.check_circle;
    } else if (fail) {
      borderColor = AppColors.primaryRed;
      textColor = const Color(0xFFFF8A80);
      icon = Icons.error;
    } else if (_busy) {
      borderColor = AppColors.primaryRed;
      textColor = AppColors.textPrimary;
      icon = Icons.hourglass_top;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
              Text(
                _busy ? '转换中…' : (ok ? '成功' : (fail ? '失败' : '就绪')),
                style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500, fontFamily: AppColors.fontFamily),
              ),
              const Spacer(),
              if (_busy)
                SizedBox(
                  width: 140,
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: AppColors.borderColor,
                    color: AppColors.primaryRed,
                    minHeight: 4,
                  ),
                ),
              if (_busy)
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontFamily: AppColors.fontFamily),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 140),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.innerBg, borderRadius: BorderRadius.circular(6)),
            child: SingleChildScrollView(
              child: Text(
                _status.isEmpty ? '选择源文件后点击"开始转换"。' : _status,
                style: TextStyle(fontSize: 12, color: textColor, fontFamily: 'Consolas, ${AppColors.fontFamily}', height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFile(String path) {
    try {
      Process.run('explorer', ['/select,', path.replaceAll('/', '\\')]);
    } catch (_) {}
  }
}

/// 无边框窗口控制按钮（最小化 / 最大化 / 关闭），带悬停高亮。
class _WinButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool danger;
  const _WinButton({required this.icon, required this.onTap, this.tooltip, this.danger = false});

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color color = widget.danger
        ? (_hover ? Colors.white : AppColors.textSecondary)
        : (_hover ? Colors.white : AppColors.textSecondary);
    final Color bg = widget.danger
        ? (_hover ? AppColors.primaryRed : Colors.transparent)
        : (_hover ? const Color(0x33FFFFFF) : Colors.transparent);
    return Tooltip(
      message: widget.tooltip ?? '',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 34,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
            child: Icon(widget.icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }
}