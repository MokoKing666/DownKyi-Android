import '../core/protobuf_lite.dart';
import 'models.dart';

/// 解析 `/x/v2/dm/web/seg.so` 返回的 protobuf 弹幕分片。
///
/// message DmSegMobileReply { repeated DanmakuElem elems = 1; }
/// message DanmakuElem {
///   int64  id       = 1;
///   int32  progress = 2;   // 出现时间（毫秒）
///   int32  mode     = 3;   // 1-3 滚动，4 底部，5 顶部
///   int32  fontsize = 4;
///   uint32 color    = 5;
///   string midHash  = 6;
///   string content  = 7;
///   int64  ctime    = 8;
///   ...
/// }
class DanmakuParser {
  const DanmakuParser._();

  static List<DanmakuItem> parseSegment(List<int> bytes) {
    final result = <DanmakuItem>[];
    if (bytes.isEmpty) return result;
    try {
      final reader = ProtoReader(bytes);
      while (!reader.isAtEnd) {
        final tag = reader.readVarint();
        final field = tag >> 3;
        final wireType = tag & 7;
        if (field == 1 && wireType == 2) {
          final item = _parseElem(reader.readBytes());
          if (item != null) result.add(item);
        } else {
          reader.skip(wireType);
        }
      }
    } on FormatException {
      // 分片损坏时返回已解析部分，不影响整体下载
    }
    return result;
  }

  static DanmakuItem? _parseElem(List<int> bytes) {
    var progress = 0;
    var mode = 1;
    var fontSize = 25;
    var color = 0xFFFFFF;
    var content = '';
    try {
      final reader = ProtoReader(bytes);
      while (!reader.isAtEnd) {
        final tag = reader.readVarint();
        final field = tag >> 3;
        final wireType = tag & 7;
        switch (field) {
          case 2:
            progress = reader.readVarint();
            break;
          case 3:
            mode = reader.readVarint();
            break;
          case 4:
            fontSize = reader.readVarint();
            break;
          case 5:
            color = reader.readVarint();
            break;
          case 7:
            content = reader.readString();
            break;
          default:
            reader.skip(wireType);
        }
      }
    } on FormatException {
      return null;
    }
    if (content.isEmpty) return null;
    return DanmakuItem(
      progressMs: progress,
      mode: mode <= 0 ? 1 : mode,
      fontSize: fontSize <= 0 ? 25 : fontSize,
      color: color,
      content: content,
    );
  }
}
