import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../core/formatter.dart';
import '../td.dart';

/// 视频封面（带时长角标）
class VideoCover extends StatelessWidget {
  const VideoCover({
    super.key,
    required this.url,
    this.width = 120,
    this.height = 72,
    this.durationMs = 0,
  });

  final String url;
  final double width;
  final double height;
  final int durationMs;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(TdRadius.medium),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Container(color: TdPalette.gray2),
            if (url.isNotEmpty)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child:
                      Icon(Icons.broken_image_outlined, color: TdPalette.gray6),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: const TLoading(size: 16, icon: TLoadingIcon.circle),
                  );
                },
              ),
            if (durationMs > 0)
              Positioned(
                right: 4,
                bottom: 4,
                // 时长角标需要白字深底（1.x 的 TTag 不支持自定义配色，这里自绘）
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(TdRadius.small),
                  ),
                  child: Text(
                    formatDuration(durationMs),
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 视频信息行
class VideoInfoTile extends StatelessWidget {
  const VideoInfoTile({
    super.key,
    required this.title,
    required this.cover,
    this.subtitle,
    this.durationMs = 0,
    this.trailing,
    this.leading,
    this.onTap,
  });

  final String title;
  final String cover;
  final String? subtitle;
  final int durationMs;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // 官方 TCell：封面（含左侧勾选框）走 prefix，尾部控件走 trailing
    return TCell(
      title: Text(title, style: TdText.bodyMedium),
      subtitle:
          subtitle == null ? null : Text(subtitle!, style: TdText.bodySmall),
      prefix: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: TdSpacer.small),
          ],
          VideoCover(url: cover, durationMs: durationMs),
        ],
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
