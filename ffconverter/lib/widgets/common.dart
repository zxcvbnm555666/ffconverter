import 'package:flutter/material.dart';

/// 复刻参考网页的水墨国风视觉常量。
class AppColors {
  static const primaryRed = Color(0xFFD93832);
  static const primaryRedHover = Color(0xFFB62A25);
  static const primaryRedSoft = Color(0x1FD93832);
  static const cardBg = Color(0xEB161618);
  static const cardBorder = Color(0x14FFFFFF);
  static const innerBg = Color(0xFF0F0F11);
  static const inputBg = Color(0xFF2A2A2E);
  static const borderColor = Color(0xFF3A3A3E);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB8B8B8);
  static const textMuted = Color(0xFF6E6E72);
  static const toggleOff = Color(0xFF4A4A4E);

  static const fontFamily = '"PingFang SC","Microsoft YaHei",-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif';
}

/// 磨砂玻璃卡片。
class GlassCard extends StatelessWidget {
  final Widget child;
  final double width;
  const GlassCard({super.key, required this.child, this.width = 540});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x59000000), blurRadius: 50, offset: Offset(0, 20)),
          BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

/// 卡片标题，带红色竖条。
class CardHeader extends StatelessWidget {
  final String title;
  const CardHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.textPrimary, fontFamily: AppColors.fontFamily)),
      ],
    );
  }
}

/// 红色选项按钮（选中红色高亮）。
class OptionButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool enabled;
  const OptionButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = !enabled
        ? AppColors.textMuted
        : (active ? AppColors.primaryRed : AppColors.textSecondary);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: (active && enabled) ? AppColors.primaryRedSoft : Colors.transparent,
          border: Border.all(
            color: !enabled
                ? AppColors.borderColor.withOpacity(0.5)
                : (active ? AppColors.primaryRed : AppColors.borderColor),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: textColor, fontFamily: AppColors.fontFamily)),
      ),
    );
  }
}

/// 统一标签。
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: AppColors.fontFamily));
}

/// 主按钮（红色）。
class PrimaryButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool busy;
  const PrimaryButton({super.key, required this.text, required this.icon, this.onPressed, this.enabled = true, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: (enabled && !busy) ? onPressed : null,
        icon: busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18, color: Colors.white),
        label: Text(busy ? '转换中…' : text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2, fontFamily: AppColors.fontFamily)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          disabledBackgroundColor: AppColors.primaryRed.withOpacity(0.5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 6,
          shadowColor: AppColors.primaryRed,
        ).copyWith(
          overlayColor: WidgetStateProperty.all(AppColors.primaryRedHover),
        ),
      ),
    );
  }
}

/// 小动作按钮（右侧）。
class ActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  const ActionButton({super.key, required this.text, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14, color: Colors.white),
        label: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: AppColors.fontFamily)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      );
}

/// 开关组件（复刻网页 slider-toggle）。
class ToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const ToggleSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primaryRed,
        activeTrackColor: AppColors.primaryRed.withValues(alpha: 0.6),
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: AppColors.toggleOff,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}

/// 两列设置网格。
class SettingsGrid extends StatelessWidget {
  final List<Widget> children;
  const SettingsGrid({super.key, required this.children});
  @override
  Widget build(BuildContext context) => GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 18,
          mainAxisSpacing: 18,
          childAspectRatio: 6.2,
        ),
        children: children,
      );
}
