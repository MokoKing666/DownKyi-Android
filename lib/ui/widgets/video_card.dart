import 'package:flutter/material.dart';
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
                  return Center(
                    child: TDLoading(
                      size: TDLoadingSize.small,
                      icon: TDLoadingIcon.circle,
                      iconColor: TdPalette.brand,
                    ),
                  );
                },
              ),
            if (durationMs > 0)
              Positioned(
                right: 4,
                bottom: 4,
                // 时长角标用官方 TDTag，配色仍按封面上的深色底来给
                child: TDTag(
                  formatDuration(durationMs),
                  size: TDTagSize.small,
                  textColor: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: TdSpacer.small),
            ],
            VideoCover(url: cover, durationMs: durationMs),
            const SizedBox(width: TdSpacer.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TdText.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      style: TdText.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: TdSpacer.xs),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
