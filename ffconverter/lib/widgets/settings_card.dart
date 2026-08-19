import 'package:flutter/material.dart';
import '../models/settings.dart';
import 'common.dart';

/// 目标设置卡片：封装格式 / 编码 / 模式 / 硬件加速 / 视频音频参数。
class SettingsCard extends StatefulWidget {
  final ConvertSettings settings;
  final Set<EncoderHw> hwEncoders;

  const SettingsCard({
    super.key,
    required this.settings,
    required this.hwEncoders,
  });

  @override
  State<SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<SettingsCard> {
  late ConvertSettings s;

  @override
  void initState() {
    super.initState();
    s = widget.settings;
    s.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant SettingsCard old) {
    super.didUpdateWidget(old);
    if (old.settings != widget.settings) {
      old.settings.removeListener(_onChange);
      s = widget.settings;
      s.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    s.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() { if (mounted) setState(() {}); }

  void _update(void Function(ConvertSettings s) fn) => s.update(fn);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: 660,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(title: '目标设置'),
          const SizedBox(height: 18),
          _buildTabs(),
          const SizedBox(height: 14),
          _row('转换模式', _modeRow()),
          const SizedBox(height: 20),
          _row('视频编码', _videoCodecRow(), enabled: !_fast),
          _divider(),
          _row('音频编码', _audioCodecRow(), enabled: !_fast),
          _divider(),
          _row('解码方式', _decoderRow(), enabled: !_fast),
          _divider(),
          _row('编码方案', _encoderRow(), enabled: !_fast),
          _divider(),
          _row('视频参数', _qualityRow(), enabled: !_fast),
          _divider(),
          _row('分辨率', _resolutionDropdown(), enabled: !_fast),
          _divider(),
          _row('帧率', _fpsRow(), enabled: !_fast),
          _divider(),
          _row('音频参数', _audioRow(), enabled: !_fast),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tab('输出格式', true),
          ...kContainers.take(8).map((c) => _tab(c.label, s.container.id == c.id, () {
                _update((s) => s.container = c);
              })),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, [VoidCallback? onTap]) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryRed : Colors.transparent,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            border: Border(bottom: BorderSide(color: active ? AppColors.primaryRed : AppColors.borderColor, width: 2)),
          ),
          child: Text(label, style: TextStyle(fontSize: 14, color: active ? Colors.white : AppColors.textSecondary, fontFamily: AppColors.fontFamily)),
        ),
      );

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: Color(0x14FFFFFF), height: 1),
      );

  Widget _row(String label, Widget child, {bool enabled = true}) {
    final labelColor = enabled ? AppColors.textSecondary : AppColors.textMuted;
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: labelColor, fontFamily: AppColors.fontFamily))),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  bool get _fast => s.mode == ConvertMode.fast;

  Widget _videoCodecRow() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kVideoCodecs.map((c) => OptionButton(
              label: c.label,
              active: s.videoCodec.id == c.id,
              onTap: () => _update((s) => s.videoCodec = c),
            )).toList(),
      );

  Widget _audioCodecRow() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kAudioCodecs.map((c) => OptionButton(
              label: c.label,
              active: s.audioCodec.id == c.id,
              onTap: () => _update((s) => s.audioCodec = c),
            )).toList(),
      );

  Widget _modeRow() => Row(
        children: [
          _Pill('快速转换', s.mode == ConvertMode.fast, () => _update((s) => s.mode = ConvertMode.fast)),
          const SizedBox(width: 8),
          _Pill('重新编码', s.mode == ConvertMode.reencode, () => _update((s) => s.mode = ConvertMode.reencode)),
        ],
      );

  /// 解码方式：自动(D3D优先) / 软件。
  Widget _decoderRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DecoderMode.values.map((d) => OptionButton(
            label: d.label,
            active: s.decoderMode == d,
            onTap: () => _update((s) => s.decoderMode = d),
          )).toList(),
    );
  }

  /// 编码方案：软件 / CUDA / Intel / AMD（不可用的置灰）。
  Widget _encoderRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EncoderHw.values.map((e) {
        final available = widget.hwEncoders.contains(e);
        final active = s.encoderHw == e;
        return OptionButton(
          label: e.label,
          active: active && available,
          enabled: available,
          onTap: () => _update((s) => s.encoderHw = e),
        );
      }).toList(),
    );
  }

  /// 视频参数：质量 / 码率互斥——选质量只显示滑块，选码率只显示码率输入。
  Widget _qualityRow() {
    return Row(
      children: [
        _Pill('质量', !s.useBitrate, () => _update((s) => s.useBitrate = false)),
        const SizedBox(width: 6),
        _Pill('码率', s.useBitrate, () => _update((s) => s.useBitrate = true)),
        const SizedBox(width: 12),
        Expanded(
          child: s.useBitrate ? _bitrateInput() : _qualitySlider(),
        ),
      ],
    );
  }

  Widget _qualitySlider() {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primaryRed,
              inactiveTrackColor: AppColors.borderColor,
              thumbColor: Colors.white,
              overlayColor: AppColors.primaryRedSoft,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 4,
            ),
            child: Slider(
              value: s.quality.toDouble(),
              min: 0, max: 100, divisions: 100,
              onChanged: (v) => _update((s) => s.quality = v.round()),
            ),
          ),
        ),
        SizedBox(width: 36, child: Text('${s.quality}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: AppColors.fontFamily), textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _bitrateInput() {
    return Row(
      children: [
        _textField(
          width: 110,
          value: s.bitrateMbps != null ? s.bitrateMbps.toString() : '',
          suffix: 'Mbps',
          number: true,
          onChanged: (v) {
            final d = double.tryParse(v);
            _update((s) => s.bitrateMbps = d);
          },
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('0 表示自动', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: AppColors.fontFamily)),
        ),
      ],
    );
  }

  Widget _resolutionDropdown() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _resKey(),
            dropdownColor: AppColors.inputBg,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: AppColors.fontFamily),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.primaryRed)),
            ),
            items: _resOptions.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontFamily: AppColors.fontFamily))))
                .toList(),
            onChanged: (val) => _applyRes(val),
          ),
        ),
        const SizedBox(width: 8),
        if (_resKey() == 'custom')
          _textField(
            width: 130,
            value: _customResText(),
            onChanged: (v) {
              final m = RegExp(r'(\d+)\s*[x×]\s*(\d+)').firstMatch(v);
              if (m != null) {
                final w = int.parse(m.group(1)!);
                final h = int.parse(m.group(2)!);
                _update((s) { s.resW = w; s.resH = h; });
              }
            },
          ),
      ],
    );
  }

  // 分辨率预设
  final Map<String, String> _resOptions = {
    'native': '原生分辨率',
    '2160p': '4K (3840×2160)',
    '1080p': '1080P (1920×1080)',
    '720p': '720P (1280×720)',
    '480p': '480P (854×480)',
    'custom': '自定义',
  };

  /// 当前设置对应的下拉 key。
  String _resKey() {
    if (s.resW == null || s.resH == null) return 'native';
    if (s.resW == 3840 && s.resH == 2160) return '2160p';
    if (s.resW == 1920 && s.resH == 1080) return '1080p';
    if (s.resW == 1280 && s.resH == 720) return '720p';
    if (s.resW == 854 && s.resH == 480) return '480p';
    return 'custom';
  }

  void _applyRes(String? val) {
    if (val == null) return;
    switch (val) {
      case 'native':
        _update((s) { s.resW = null; s.resH = null; });
      case '2160p':
        _update((s) { s.resW = 3840; s.resH = 2160; });
      case '1080p':
        _update((s) { s.resW = 1920; s.resH = 1080; });
      case '720p':
        _update((s) { s.resW = 1280; s.resH = 720; });
      case '480p':
        _update((s) { s.resW = 854; s.resH = 480; });
      default:
        break; // custom 保留当前值，等待输入
    }
  }

  String _customResText() => _resKey() == 'custom' ? '${s.resW} × ${s.resH}' : '';

  Widget _fpsRow() => Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primaryRed,
                inactiveTrackColor: AppColors.borderColor,
                thumbColor: Colors.white,
                overlayColor: AppColors.primaryRedSoft,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackHeight: 4,
              ),
              child: Slider(
                value: (s.fps ?? 30).toDouble(),
                min: 15, max: 120, divisions: 105,
                onChanged: (v) => _update((s) => s.fps = v.round()),
              ),
            ),
          ),
          SizedBox(width: 56, child: Text('${s.fps ?? 30} fps', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: AppColors.fontFamily), textAlign: TextAlign.right)),
        ],
      );

  Widget _audioRow() => Row(
        children: [
          _textField(
            width: 90,
            value: '${s.audioBitrateKbps}',
            suffix: 'kbps',
            number: true,
            onChanged: (v) {
              final i = int.tryParse(v);
              if (i != null) _update((s) => s.audioBitrateKbps = i);
            },
          ),
          const SizedBox(width: 8),
          const Text('采样率', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: AppColors.fontFamily)),
          const SizedBox(width: 8),
          Text('${s.sampleRateHz} Hz', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: AppColors.fontFamily)),
          const SizedBox(width: 8),
          const Text('声道', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: AppColors.fontFamily)),
          const SizedBox(width: 4),
          Text(s.channels == 1 ? '单声道' : s.channels == 6 ? '5.1' : '立体声', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: AppColors.fontFamily)),
        ],
      );

  Widget _textField({required double width, required String value, String? suffix, bool number = false, required ValueChanged<String> onChanged}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: TextEditingController(text: value),
        onChanged: onChanged,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 13, color: Colors.white, fontFamily: AppColors.fontFamily),
        decoration: InputDecoration(
          isDense: true,
          suffixText: suffix,
          suffixStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.inputBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.primaryRed)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }

}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill(this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            border: Border.all(color: active ? Colors.white : AppColors.borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, color: active ? AppColors.primaryRed : AppColors.textSecondary, fontWeight: active ? FontWeight.w500 : FontWeight.normal, fontFamily: AppColors.fontFamily)),
        ),
      );
}