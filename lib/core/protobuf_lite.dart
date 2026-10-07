import 'dart:convert';
import 'dart:typed_data';

/// 极简 protobuf 读取器：只实现弹幕接口需要的 varint / length-delimited 解析，
/// 避免为了一个接口引入 protoc 代码生成。
class ProtoReader {
  ProtoReader(this._bytes);

  final List<int> _bytes;
  int _position = 0;

  bool get isAtEnd => _position >= _bytes.length;

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_position >= _bytes.length) {
        throw const FormatException('varint 越界');
      }
      final byte = _bytes[_position++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
      if (shift > 63) throw const FormatException('varint 过长');
    }
    return result;
  }

  Uint8List readBytes() {
    final length = readVarint();
    final end = _position + length;
    if (end > _bytes.length) throw const FormatException('length-delimited 越界');
    final value = Uint8List.fromList(_bytes.sublist(_position, end));
    _position = end;
    return value;
  }

  String readString() => utf8.decode(readBytes(), allowMalformed: true);

  int readFixed32() {
    if (_position + 4 > _bytes.length) throw const FormatException('fixed32 越界');
    final value = _bytes[_position] |
        (_bytes[_position + 1] << 8) |
        (_bytes[_position + 2] << 16) |
        (_bytes[_position + 3] << 24);
    _position += 4;
    return value;
  }

  int readFixed64() {
    if (_position + 8 > _bytes.length) throw const FormatException('fixed64 越界');
    var value = 0;
    for (var index = 7; index >= 0; index--) {
      value = (value << 8) | _bytes[_position + index];
    }
    _position += 8;
    return value;
  }

  /// 跳过不关心的字段
  void skip(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
        break;
      case 1:
        readFixed64();
        break;
      case 2:
        readBytes();
        break;
      case 5:
        readFixed32();
        break;
      default:
        throw FormatException('不支持的 wireType: $wireType');
    }
  }
}
