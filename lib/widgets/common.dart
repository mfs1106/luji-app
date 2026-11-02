import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 白卡容器：圆角 16、白底、卡片投影
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.radius = AppDimens.radiusCard,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppDimens.cardPadding),
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [AppShadows.card],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// 区块标题行：左标题 + 右操作
class SectionHeaderRow extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const SectionHeaderRow({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          if (actionText != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionText!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.primary)),
            ),
        ],
      ),
    );
  }
}

/// 主按钮：高 48–50、圆角 14、主色填充、投影
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final IconData? icon;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 50,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusButton),
        boxShadow: bg == AppColors.primary
            ? const [AppShadows.primaryButton]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 次要按钮：白底 + 1px 描边
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text)),
          ),
        ),
      ),
    );
  }
}

/// 小标签：如「已验票」「待用券」
class TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const TagChip({
    super.key,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
    );
  }
}

/// 开关：44×26、圆角 13；开=主色圆点居右，关=灰圆点居左
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// 图标容器：40×40 彩色圆底 + 线性图标（设计稿宫格/列表通用）
class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  const IconBubble({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Center(child: Icon(icon, size: size * 0.5, color: color)),
    );
  }
}

/// 城市/分类筛选胶囊
class FilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const FilterChipPill({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.secondary)),
      ),
    );
  }
}

/// 线性进度条（预算进度等）
class AppProgressBar extends StatelessWidget {
  final double value; // 0~1
  final Color? color;
  final Color? background;
  final double height;

  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.background,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: background ?? AppColors.border,
        valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
      ),
    );
  }
}
