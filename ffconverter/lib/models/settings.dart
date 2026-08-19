/// 转换设置相关数据模型与命令构建逻辑。
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// 封装格式。
class ContainerFormat {
  final String id;
  final String label;
  final String ext;
  const ContainerFormat(this.id, this.label, this.ext);
}

const kContainers = [
  ContainerFormat('mp4', 'MP4', 'mp4'),
  ContainerFormat('flv', 'FLV', 'flv'),
  ContainerFormat('mkv', 'MKV', 'mkv'),
  ContainerFormat('mov', 'MOV', 'mov'),
  ContainerFormat('avi', 'AVI', 'avi'),
  ContainerFormat('webm', 'WebM', 'webm'),
  ContainerFormat('ts', 'TS', 'ts'),
  ContainerFormat('m4v', 'M4V', 'm4v'),
  ContainerFormat('wmv', 'WMV', 'wmv'),
  ContainerFormat('3gp', '3GP', '3gp'),
];

/// 视频编码。
class VideoCodec {
  final String id;
  final String label;
  final List<String> hwEncoders; // 硬件加速对应的编码器
  const VideoCodec(this.id, this.label, [this.hwEncoders = const []]);
}

const kVideoCodecs = [
  VideoCodec('libx264', 'H.264', ['h264_nvenc', 'h264_qsv', 'h264_amf']),
  VideoCodec('libx265', 'H.265', ['hevc_nvenc', 'hevc_qsv', 'hevc_amf']),
  VideoCodec('libaom-av1', 'AV1', ['av1_nvenc']),
  VideoCodec('libvpx-vp9', 'VP9', []),
  VideoCodec('mpeg4', 'MPEG-4', []),
  VideoCodec('libvvenc', 'VVC', []),
];

/// 音频编码。
class AudioCodec {
  final String id;
  final String label;
  final String defaultBitrate;
  const AudioCodec(this.id, this.label, this.defaultBitrate);
}

const kAudioCodecs = [
  AudioCodec('aac', 'AAC', '192k'),
  AudioCodec('libmp3lame', 'MP3', '192k'),
  AudioCodec('libopus', 'Opus', '128k'),
  AudioCodec('flac', 'FLAC', '0'),
  AudioCodec('copy', '复制(不重编码)', '0'),
];

/// 转换模式。
enum ConvertMode { fast, reencode }

/// 编码硬件方案。
enum EncoderHw {
  software('software', '软件编码', ''),
  cuda('cuda', 'CUDA (NVIDIA)', 'nvenc'),
  qsv('qsv', 'QSV (Intel)', 'qsv'),
  amf('amf', 'AMF (AMD)', 'amf');

  final String id;
  final String label;
  final String suffix; // 硬件编码器后缀，用于从 VideoCodec.hwEncoders 匹配
  const EncoderHw(this.id, this.label, this.suffix);
}

/// 解码方式。
enum DecoderMode {
  autoD3d('autoD3d', '自动 (D3D11 优先)'),
  software('software', '软件解码');

  final String id;
  final String label;
  const DecoderMode(this.id, this.label);
}

/// 完整转换设置。
class ConvertSettings extends ChangeNotifier {
  ConvertSettings({
    ContainerFormat? container,
    VideoCodec? videoCodec,
    AudioCodec? audioCodec,
    this.mode = ConvertMode.fast,
    this.encoderHw = EncoderHw.software,
    this.decoderMode = DecoderMode.autoD3d,
    this.quality = 60,
    this.useBitrate = false,
    this.resW,
    this.resH,
    this.bitrateMbps,
    this.fps,
    this.audioBitrateKbps = 192,
    this.sampleRateHz = 48000,
    this.channels = 2,
  })  : container = container ?? kContainers[0],
        videoCodec = videoCodec ?? kVideoCodecs[0],
        audioCodec = audioCodec ?? kAudioCodecs[0];

  ContainerFormat container;
  VideoCodec videoCodec;
  AudioCodec audioCodec;
  ConvertMode mode;
  EncoderHw encoderHw; // 编码硬件方案
  DecoderMode decoderMode; // 解码方式
  int quality; // 0-100, 越高越好
  bool useBitrate; // true=用码率, false=用质量(互斥)
  int? resW;
  int? resH;
  double? bitrateMbps;
  int? fps;
  int audioBitrateKbps;
  int sampleRateHz;
  int channels;

  /// 修改设置并通知监听者。
  void update(void Function(ConvertSettings s) fn) {
    fn(this);
    notifyListeners();
  }

  /// 构建 ffmpeg 参数（不含 -i 输入与输出文件）。
  List<String> buildArgs() {
    if (mode == ConvertMode.fast) {
      // 快速转封装：复制视频流。
      // FLV 容器不支持 opus 等音频，遇到时自动用 AAC 重新编码音频。
      final audioArgs = container.id == 'flv'
          ? ['-c:a', 'aac', '-b:a', '${audioBitrateKbps}k']
          : ['-c:a', 'copy'];
      return [
        '-c:v', 'copy',
        ...audioArgs,
        if (container.id == 'mp4' || container.id == 'mov') ...['-movflags', 'faststart'],
      ];
    }

    final args = <String>[];
    // 视频
    final isHwEnc = encoderHw != EncoderHw.software && videoCodec.hwEncoders.isNotEmpty;
    final vEnc = isHwEnc
        ? _hwEncoderFor(videoCodec, encoderHw)
        : videoCodec.id;
    args.addAll(['-c:v', vEnc]);

    final isNvenc = vEnc.contains('nvenc');
    final isQsv = vEnc.contains('qsv');
    final isAmf = vEnc.contains('amf');

    // 视频质量/码率（互斥）：useBitrate=true 用码率，false 用质量
    if (useBitrate && bitrateMbps != null) {
      // 码率模式：直接指定视频码率
      if (isNvenc) {
        args.addAll(['-rc', 'vbr', '-b:v', '${(bitrateMbps! * 1000).round()}k', '-maxrate', '${(bitrateMbps! * 1000 * 1.2).round()}k', '-bufsize', '${(bitrateMbps! * 1000 * 2).round()}k']);
        args.addAll(['-preset', _nvencPreset(quality)]);
      } else {
        args.addAll(['-b:v', '${(bitrateMbps! * 1000).round()}k']);
        if (videoCodec.id == 'libx264' || videoCodec.id == 'libx265') {
          args.addAll(['-preset', 'medium']);
        }
      }
    } else {
      // 质量模式：不同编码器用不同质量参数名
      if (isNvenc) {
        final cq = (28 - (quality / 100) * 28).round().clamp(0, 51);
        args.addAll(['-rc', 'vbr', '-cq', '$cq', '-b:v', '0']);
        args.addAll(['-preset', _nvencPreset(quality)]);
      } else if (isQsv || isAmf) {
        final gq = (28 - (quality / 100) * 28).round().clamp(0, 51);
        args.addAll(['-global_quality', '$gq']);
      } else {
        // 软件编码
        final crf = (28 - (quality / 100) * 22).round().clamp(0, 51);
        if (videoCodec.id == 'libx264' || videoCodec.id == 'libx265') {
          args.addAll(['-crf', '$crf', '-preset', 'medium']);
        }
      }
    }

    // 分辨率缩放（仅在重新编码时生效；已在 -c:v 之后）
    if (resW != null && resH != null) {
      args.addAll(['-vf', 'scale=$resW:$resH']);
    }
    if (fps != null) {
      args.addAll(['-r', '$fps']);
    }

    // 音频
    if (audioCodec.id == 'copy') {
      args.addAll(['-c:a', 'copy']);
    } else {
      args.addAll(['-c:a', audioCodec.id]);
      if (audioCodec.id != 'flac') {
        args.addAll(['-b:a', '${audioBitrateKbps}k']);
      }
      args.addAll(['-ar', '$sampleRateHz', '-ac', '$channels']);
    }

    if (container.id == 'mp4' || container.id == 'mov') {
      args.addAll(['-movflags', 'faststart']);
    }
    return args;
  }

  /// 输入阶段的硬件解码选项（必须放在 -i 之前）。ffmpeg 中 -hwaccel 是输入选项。
  /// 解码默认 d3d11va 优先，ffmpeg 在硬解失败时会自动回退软件解码。
  List<String> hwaccelInputArgs() {
    if (mode == ConvertMode.fast) return const [];
    switch (decoderMode) {
      case DecoderMode.autoD3d:
        return const ['-hwaccel', 'd3d11va'];
      case DecoderMode.software:
        return const [];
    }
  }

  String _hwEncoderFor(VideoCodec codec, EncoderHw hw) {
    // 用后缀(nvenc/qsv/amf)匹配该视频编码对应的硬件编码器
    for (final e in codec.hwEncoders) {
      if (e.contains(hw.suffix)) return e;
    }
    // 若该编码没有对应硬件编码器，回退到软件编码
    return codec.id;
  }

  String _nvencPreset(int quality) {
    // 质量高 → p7（最慢/最高质量）；质量低 → p1（最快/低质量）
    if (quality >= 85) return 'p7';
    if (quality >= 70) return 'p6';
    if (quality >= 50) return 'p5';
    if (quality >= 30) return 'p4';
    return 'p2';
  }

  /// 计算默认输出路径。
  String defaultOutput(String input, String? outDir) {
    final dir = outDir ?? p.dirname(input);
    final base = p.basenameWithoutExtension(input);
    return p.join(dir, '${base}_converted.${container.ext}');
  }
}
