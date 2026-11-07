import 'dart:io';

/// 安全文件替换：先把原文件改名备份，再把临时文件改名到位，失败回滚。
///
/// 之前 `_injectMetadata` 的顺序是「先删原文件、再 rename 临时文件」——
/// rename 一旦抛异常（权限、占用、跨设备），原成品已经没了，
/// 只留下一个 `.meta.` 临时文件。这个函数把顺序改成：
///
/// 1. 原文件 → `.bak`（同一文件系统内 rename，基本原子）
/// 2. 临时文件 → 目标位置
/// 3. 第 2 步抛异常 → 从 `.bak` 回滚，原文件原样还在
/// 4. 成功 → 删备份
///
/// 任何时刻磁盘上都至少存在一份有效成品，没有「两份都不在」的窗口。
class SafeReplace {
  SafeReplace._();

  /// 把 [tempPath] 安全替换到 [targetPath]。
  /// [tempPath] 必须已存在且通过调用方自己的校验；本函数只保证替换过程可回滚。
  static Future<void> replace(String tempPath, String targetPath) async {
    final backup = '$targetPath.bak';
    await _deleteIfExists(backup);

    // 1. 原文件改名备份。原文件不存在时直接跳过（视为首次写入）。
    final target = File(targetPath);
    final hadOriginal = await target.exists();
    if (hadOriginal) {
      await target.rename(backup);
    }

    try {
      // 2. 临时文件改名到位
      await File(tempPath).rename(targetPath);
    } catch (error) {
      // 3. 失败回滚：把备份改回来
      if (hadOriginal) {
        try {
          await File(backup).rename(targetPath);
        } catch (rollbackError) {
          // 回滚也失败时把两份路径都写进异常，让用户至少有文件可捡
          throw StateError(
            '替换失败且回滚失败：原始备份在 $backup，临时文件在 $tempPath'
            '（$rollbackError）',
          );
        }
      }
      rethrow;
    }

    // 4. 成功才删备份
    await _deleteIfExists(backup);
  }

  static Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 清理失败不影响主流程
    }
  }
}
