import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/settings.dart';

/// ffmpeg 运行时封装：定位可执行文件、探测能力、构建命令并执行、解析进度。
class FFmpegRunner {
  FFmpegRunner._();
  static final FFmpegRunner instance = FFmpegRunner._();

  String? _exePath;
  bool? _available;
  Process? _currentProc;

  /// 当前正在执行的 ffmpeg 进程（供停止按钮使用）。
  Process? get currentProcess => _currentProc;

  /// 结束当前正在执行的转换进程。
  void stop() {
    final p = _currentProc;
    if (p != null) {
      try {
        p.kill(ProcessSignal.sigterm);
      } catch (_) {
        try { p.kill(); } catch (_) {}
      }
    }
  }

  /// 定位 ffmpeg.exe：优先可执行文件同目录，其次 PATH。
  Future<String> get executable async {
    if (_exePath != null) return _exePath!;
    // 1) 与 exe 同目录（发布版通过 CMake 复制到此）
    final local = p.join(p.dirname(Platform.resolvedExecutable), 'ffmpeg.exe');
    if (await File(local).exists()) {
      _exePath = local;
      return _exePath!;
    }
    // 2) 开发态：项目 bin/ffmpeg.exe
    final dev = p.join(
      p.dirname(p.dirname(Platform.resolvedExecutable)),
      '..',
      'bin',
      'ffmpeg.exe',
    );
    if (await File(dev).exists()) {
      _exePath = dev;
      return _exePath!;
    }
    // 3) PATH
    final which = await Process.run('where', ['ffmpeg.exe']);
    if (which.exitCode == 0) {
      _exePath = which.stdout.toString().trim().split('\n').first.trim();
      return _exePath!;
    }
    throw StateError('未找到 ffmpeg.exe，请将其放在程序目录或 PATH 中。');
  }

  Future<bool> get isAvailable async {
    if (_available != null) return _available!;
    try {
      final r = await Process.run(await executable, ['-version']);
      _available = r.exitCode == 0;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  /// 探测可用的编码硬件方案（CUDA / QSV / AMF）。
  /// 基于实际可用的硬件编码器并实际尝试编码一次来确认；software 永远可用。
  Future<Set<EncoderHw>> detectHwAccel() async {
    final exe = await executable;
    // 获取编码器列表
    String? encList;
    try {
      final r = await Process.run(exe, ['-hide_banner', '-encoders']);
      encList = '${r.stdout}';
    } catch (_) {}
    bool hasEnc(String id) => encList != null && RegExp('^ .{6}\\s$id\\b', multiLine: true).hasMatch(encList);

    // 真实尝试一次编码：极短的空输入 + 指定编码器 → null 输出
    Future<bool> probeEncoder(String enc) async {
      try {
        final r = await Process.run(exe, [
          '-hide_banner', '-y',
          '-f', 'lavfi', '-i', 'nullsrc=s=128x128:d=0.2',
          '-t', '0.2',
          '-c:v', enc,
          '-b:v', '1000k',
          '-f', 'null', '-',
        ]);
        return r.exitCode == 0;
      } catch (_) {
        return false;
      }
    }

    final out = <EncoderHw>{EncoderHw.software};
    // NVIDIA：优先用 h264_nvenc 试探
    if (hasEnc('h264_nvenc') || hasEnc('hevc_nvenc') || hasEnc('av1_nvenc')) {
      final e = hasEnc('h264_nvenc') ? 'h264_nvenc' : (hasEnc('hevc_nvenc') ? 'hevc_nvenc' : 'av1_nvenc');
      if (await probeEncoder(e)) out.add(EncoderHw.cuda);
    }
    // Intel QSV
    if (hasEnc('h264_qsv') || hasEnc('hevc_qsv') || hasEnc('av1_qsv') || hasEnc('vp9_qsv')) {
      final e = hasEnc('h264_qsv') ? 'h264_qsv' : (hasEnc('hevc_qsv') ? 'hevc_qsv' : (hasEnc('av1_qsv') ? 'av1_qsv' : 'vp9_qsv'));
      if (await probeEncoder(e)) out.add(EncoderHw.qsv);
    }
    // AMD AMF
    if (hasEnc('h264_amf') || hasEnc('hevc_amf') || hasEnc('av1_amf')) {
      final e = hasEnc('h264_amf') ? 'h264_amf' : (hasEnc('hevc_amf') ? 'hevc_amf' : 'av1_amf');
      if (await probeEncoder(e)) out.add(EncoderHw.amf);
    }
    return out;
  }

  /// 异步执行转换，[onProgress] 接收 0-1 的进度与速度文本。
  /// 返回 FFmpegResult（含退出码与日志末尾）。
  Future<FFmpegResult> convert({
    required String input,
    required String output,
    required List<String> args,
    required void Function(double progress, String speed) onProgress,
    required Duration? totalDuration,
    void Function(String line)? onLog,
    void Function(String command)? onCommand,
    List<String> preInputArgs = const [],
  }) async {
    final exe = await executable;
    // -hwaccel 等输入选项必须放在 -i 之前
    final cmd = ['-hide_banner', '-y', ...preInputArgs, '-i', input, ...args, output];
    if (onCommand != null) {
      onCommand('ffmpeg ' + cmd.map(_quote).join(' '));
    }
    final proc = await Process.start(exe, cmd);
    _currentProc = proc;
    double lastP = 0;
    final Duration? dur = totalDuration;
    final lines = <String>[];

    void handleLine(String line) {
      onLog?.call(line);
      lines.add(line);
      if (lines.length > 400) lines.removeAt(0);
      final t = _parseTime(line);
      final speed = _parseSpeed(line);
      if (t != null) {
        if (dur != null && dur.inMilliseconds > 0) {
          lastP = (t.inMilliseconds / dur.inMilliseconds).clamp(0, 1);
        }
        onProgress(lastP, speed ?? '');
      } else if (speed != null) {
        onProgress(lastP, speed);
      }
    }

    proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(handleLine);
    proc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(handleLine);

    final code = await proc.exitCode;
    if (identical(_currentProc, proc)) _currentProc = null;
    return FFmpegResult(code: code, logTail: lines);
  }

  String _quote(String s) {
    if (RegExp(r'[\s"]').hasMatch(s)) {
      return '"${s.replaceAll('"', '\\"')}"';
    }
    return s;
  }

  Duration? _parseTime(String line) {
    final m = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(line);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final s = double.parse(m.group(3)!);
    return Duration(
      hours: h,
      minutes: min,
      milliseconds: (s * 1000).round(),
    );
  }

  String? _parseSpeed(String line) {
    final m = RegExp(r'(\d+(?:\.\d+)?x)').firstMatch(line);
    return m?.group(1);
  }

  /// 用 ffmpeg -i 解析源文件信息（项目无 ffprobe，复用 ffmpeg）。
  Future<MediaInfo> probe(String input) async {
    final exe = await executable;
    final r = await Process.run(exe, ['-hide_banner', '-i', input]);
    final text = '${r.stderr}${r.stdout}';
    return MediaInfo.parse(text, input);
  }

  /// 抽取首帧作为预览缩略图，返回图片路径。
  Future<File?> extractThumbnail(String input) async {
    try {
      final dir = await getTemporaryDirectory();
      final name = p.basenameWithoutExtension(input);
      final out = p.join(dir.path, '${name}_thumb.jpg');
      final r = await Process.run(await executable, [
        '-hide_banner',
        '-y',
        '-ss',
        '00:00:01',
        '-i',
        input,
        '-frames:v',
        '1',
        '-vf',
        'scale=480:-1',
        out,
      ]);
      if (r.exitCode == 0 && await File(out).exists()) {
        return File(out);
      }
    } catch (_) {}
    return null;
  }
}

/// 解析后的媒体信息。
class MediaInfo {
  MediaInfo({
    this.duration,
    this.videoCodec,
    this.audioCodec,
    this.width,
    this.height,
    this.sizeBytes,
  });

  final Duration? duration;
  final String? videoCodec;
  final String? audioCodec;
  final int? width;
  final int? height;
  final int? sizeBytes;

  static MediaInfo parse(String text, String path) {
    Duration? duration;
    String? videoCodec;
    String? audioCodec;
    int? width;
    int? height;

    final dM = RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.\d+)').firstMatch(text);
    if (dM != null) {
      duration = Duration(
        hours: int.parse(dM.group(1)!),
        minutes: int.parse(dM.group(2)!),
        milliseconds: (double.parse(dM.group(3)!) * 1000).round(),
      );
    }

    // 视频流
    final vM = RegExp(
            r'Stream #\d+:\d+.*?Video:\s*(\w+).*?(\d{2,5})x(\d{2,5})')
        .firstMatch(text);
    if (vM != null) {
      videoCodec = vM.group(1);
      width = int.tryParse(vM.group(2)!);
      height = int.tryParse(vM.group(3)!);
    }

    final aM = RegExp(r'Stream #\d+:\d+.*?Audio:\s*(\w+)').firstMatch(text);
    if (aM != null) {
      audioCodec = aM.group(1);
    }

    int? size;
    try {
      size = File(path).lengthSync();
    } catch (_) {}

    return MediaInfo(
      duration: duration,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      width: width,
      height: height,
      sizeBytes: size,
    );
  }
}

/// ffmpeg 执行结果。
class FFmpegResult {
  final int code;
  final List<String> logTail;
  const FFmpegResult({required this.code, required this.logTail});

  bool get success => code == 0;
  /// 返回日志末尾的错误关键字行（多条用换行连接）。
  String get errorMessage {
    if (success) return '';
    final keywords = RegExp(
      r'(Error|error|Failed|Invalid|Cannot|cannot|No such|Conversion failed)',
      caseSensitive: false,
    );
    final hits = <String>[];
    for (final l in logTail.reversed) {
      if (keywords.hasMatch(l)) {
        final t = l.trim();
        if (t.isNotEmpty && !hits.contains(t)) hits.insert(0, t);
        if (hits.length >= 4) break;
      }
    }
    if (hits.isEmpty) return '退出码 $code';
    return hits.join('\n');
  }
}
