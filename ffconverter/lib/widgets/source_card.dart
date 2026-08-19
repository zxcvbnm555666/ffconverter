import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../ffmpeg/ffmpeg_runner.dart';
import '../models/settings.dart';
import 'common.dart';

/// 源文件卡片：拖放/选择、信息展示、预览缩略图、开始转换。
class SourceCard extends StatefulWidget {
  final ConvertSettings settings;
  final String? outputDir;
  final bool busy;
  final double progress;
  final String speed;
  final VoidCallback onConvert;
  final VoidCallback onStop;
  final ValueChanged<String?> onInputChanged;

  const SourceCard({
    super.key,
    required this.settings,
    required this.outputDir,
    required this.busy,
    required this.progress,
    required this.speed,
    required this.onConvert,
    required this.onStop,
    required this.onInputChanged,
  });

  @override
  State<SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<SourceCard> {
  String? _inputPath;
  MediaInfo? _info;
  File? _thumb;
  bool _loading = false;
  bool _dragOver = false;

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (res != null && res.files.single.path != null) {
      _load(res.files.single.path!);
    }
  }

  Future<void> _load(String path) async {
    setState(() { _loading = true; _inputPath = path; });
    widget.onInputChanged(path);
    try {
      final info = await FFmpegRunner.instance.probe(path);
      final thumb = await FFmpegRunner.instance.extractThumbnail(path);
      if (mounted) setState(() { _info = info; _thumb = thumb; });
    } catch (e) {
      if (mounted) setState(() { _info = null; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _inputPath != null;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(title: '源文件'),
          const SizedBox(height: 18),
          // 拖放区
          GestureDetector(
            onTap: _pick,
            child: DropTarget(
              onDragEntered: (_) => setState(() => _dragOver = true),
              onDragExited: (_) => setState(() => _dragOver = false),
              onDragDone: (detail) {
                setState(() => _dragOver = false);
                final f = detail.files.where((e) => e.path.toLowerCase().endsWith('.mp4') || e.path.toLowerCase().endsWith('.flv') || e.path.toLowerCase().endsWith('.mkv') || e.path.toLowerCase().endsWith('.mov') || e.path.toLowerCase().endsWith('.avi') || e.path.toLowerCase().endsWith('.webm') || e.path.toLowerCase().endsWith('.ts') || e.path.toLowerCase().endsWith('.m4v') || e.path.toLowerCase().endsWith('.wmv') || e.path.toLowerCase().endsWith('.3gp') || e.path.toLowerCase().endsWith('.mpg') || e.path.toLowerCase().endsWith('.mpeg') || e.path.toLowerCase().endsWith('.vob') || e.path.toLowerCase().endsWith('.mts') || e.path.toLowerCase().endsWith('.m2ts')).firstOrNull;
                if (f != null) _load(f.path);
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _dragOver ? AppColors.primaryRed : AppColors.primaryRed.withOpacity(0.7), width: 1.5, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(10),
                  color: _dragOver ? AppColors.primaryRed.withOpacity(0.1) : AppColors.primaryRed.withOpacity(0.03),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 22, height: 22, decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle),
                              child: const Icon(Icons.play_arrow, size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            const Text('拖入视频文件', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary, fontFamily: AppColors.fontFamily)),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _pick,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7)),
                          child: const Text('选择文件', style: TextStyle(fontSize: 13, fontFamily: AppColors.fontFamily)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildPreview(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (hasFile && _info != null) _buildInfoRow(),
          const SizedBox(height: 18),
          if (widget.busy)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: widget.onStop,
                icon: const Icon(Icons.stop, size: 18, color: Colors.white),
                label: const Text('停止转换', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2, fontFamily: AppColors.fontFamily)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  disabledBackgroundColor: AppColors.primaryRed.withOpacity(0.5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 6,
                ),
              ),
            )
          else
            PrimaryButton(
              text: '开始转换',
              icon: Icons.play_arrow,
              busy: widget.busy,
              enabled: hasFile && !_loading,
              onPressed: widget.onConvert,
            ),
          if (widget.busy) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(value: widget.progress > 0 ? widget.progress : null, backgroundColor: AppColors.borderColor, color: AppColors.primaryRed),
            const SizedBox(height: 6),
            Text('${ (widget.progress * 100).toStringAsFixed(1) }%  ${widget.speed}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: AppColors.fontFamily)),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_loading) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)));
    }
    if (_thumb != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(_thumb!, height: 220, width: double.infinity, fit: BoxFit.cover),
      );
    }
    // 默认卷轴插画
    return Container(
      height: 220,
      decoration: BoxDecoration(color: AppColors.innerBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)),
      child: const Center(child: Icon(Icons.movie_outlined, size: 64, color: AppColors.textMuted)),
    );
  }

  Widget _buildInfoRow() {
    final info = _info!;
    final name = _inputPath!.split(RegExp(r'[\\/]')).last;
    final codec = '${info.videoCodec ?? '?'} / ${info.audioCodec ?? '?'}';
    final dur = info.duration;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file, size: 14, color: AppColors.primaryRed),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary, fontFamily: AppColors.fontFamily), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        Row(children: [Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle)), const SizedBox(width: 6), Text(codec, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: AppColors.fontFamily))]),
        const SizedBox(width: 12),
        Text(dur != null ? _fmt(dur) : '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: AppColors.fontFamily)),
      ],
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${_p(h)}:${_p(m)}:${_p(s)}';
    return '${_p(m)}:${_p(s)}';
  }
  String _p(int n) => n.toString().padLeft(2, '0');
}
