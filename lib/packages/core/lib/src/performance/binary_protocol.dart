import 'dart:convert';
import 'dart:typed_data';

import '../utils/logger.dart';

/// فرمت بسته binary:
/// [4 bytes magic] [4 bytes version] [4 bytes type]
/// [4 bytes payload_length] [N bytes payload]
class BinaryProtocol {
  static final Uint8List magic =
      Uint8List.fromList([0x53, 0x57, 0x4D, 0x4C]); // SWML (SweetMelon)
  static const int version = 1;
  static const int headerSize = 16;

  static const int typeJson = 1;
  static const int typeText = 2;
  static const int typeBinary = 3;
  static const int typePing = 4;
  static const int typePong = 5;

  /// رمزگذاری یک Map به binary
  static Uint8List encodeMessage(
    Map<String, dynamic> message, {
    bool compress = false,
  }) {
    final jsonStr = jsonEncode(message);
    final payload = utf8.encode(jsonStr);

    return _buildPacket(typeJson, Uint8List.fromList(payload));
  }

  /// رمزگذاری raw text
  static Uint8List encodeText(String text) {
    final payload = utf8.encode(text);
    return _buildPacket(typeText, Uint8List.fromList(payload));
  }

  /// رمزگذاری binary data
  static Uint8List encodeBinary(Uint8List data) {
    return _buildPacket(typeBinary, data);
  }

  /// ساخت packet
  static Uint8List _buildPacket(int type, Uint8List payload) {
    final buffer = ByteData(headerSize + payload.length);

    // Magic
    buffer.setUint8(0, magic[0]);
    buffer.setUint8(1, magic[1]);
    buffer.setUint8(2, magic[2]);
    buffer.setUint8(3, magic[3]);

    // Version
    buffer.setUint32(4, version, Endian.big);

    // Type
    buffer.setUint32(8, type, Endian.big);

    // Payload length
    buffer.setUint32(12, payload.length, Endian.big);

    // Payload
    final result = buffer.buffer.asUint8List();
    result.setRange(headerSize, headerSize + payload.length, payload);

    return result;
  }

  /// decode یک packet
  static BinaryPacket? decode(Uint8List data) {
    if (data.length < headerSize) {
      BridgeLogger.warn('BinaryProtocol', 'Packet too small');
      return null;
    }

    // بررسی magic
    if (data[0] != magic[0] ||
        data[1] != magic[1] ||
        data[2] != magic[2] ||
        data[3] != magic[3]) {
      BridgeLogger.warn('BinaryProtocol', 'Invalid magic bytes');
      return null;
    }

    final buffer = ByteData.sublistView(data);
    final ver = buffer.getUint32(4, Endian.big);
    final type = buffer.getUint32(8, Endian.big);
    final payloadLength = buffer.getUint32(12, Endian.big);

    if (data.length < headerSize + payloadLength) {
      BridgeLogger.warn('BinaryProtocol', 'Incomplete packet');
      return null;
    }

    final payload = data.sublist(headerSize, headerSize + payloadLength);

    return BinaryPacket(
      version: ver,
      type: type,
      payload: payload,
    );
  }

  /// decode به Map
  static Map<String, dynamic>? decodeMessage(Uint8List data) {
    final packet = decode(data);
    if (packet == null || packet.type != typeJson) return null;

    try {
      final jsonStr = utf8.decode(packet.payload);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      BridgeLogger.error('BinaryProtocol', 'Decode error: $e');
      return null;
    }
  }

  /// تبدیل به base64 برای ارسال در JS
  static String encodeToBase64(Map<String, dynamic> message) {
    final binary = encodeMessage(message);
    return base64Encode(binary);
  }

  /// decode از base64
  static Map<String, dynamic>? decodeFromBase64(String b64) {
    try {
      final bytes = base64Decode(b64);
      return decodeMessage(Uint8List.fromList(bytes));
    } catch (e) {
      BridgeLogger.error('BinaryProtocol', 'Base64 decode error: $e');
      return null;
    }
  }

  /// اندازه یک packet
  static int packetSize(int payloadLength) => headerSize + payloadLength;

  /// JS code برای binary protocol
  static String get jsBinaryCode => '''
    (function() {
      window.BinaryProtocol = {
        MAGIC: [0x53, 0x57, 0x4D, 0x4C],
        VERSION: 1,
        HEADER_SIZE: 16,
        
        TYPES: { JSON: 1, TEXT: 2, BINARY: 3, PING: 4, PONG: 5 },
        
        encode: function(message) {
          var json = JSON.stringify(message);
          var payload = new TextEncoder().encode(json);
          return this._buildPacket(this.TYPES.JSON, payload);
        },
        
        _buildPacket: function(type, payload) {
          var buffer = new ArrayBuffer(this.HEADER_SIZE + payload.length);
          var view = new DataView(buffer);
          
          view.setUint8(0, this.MAGIC[0]);
          view.setUint8(1, this.MAGIC[1]);
          view.setUint8(2, this.MAGIC[2]);
          view.setUint8(3, this.MAGIC[3]);
          view.setUint32(4, this.VERSION, false);
          view.setUint32(8, type, false);
          view.setUint32(12, payload.length, false);
          
          var bytes = new Uint8Array(buffer);
          bytes.set(payload, this.HEADER_SIZE);
          
          return bytes;
        },
        
        decode: function(bytes) {
          if (bytes.length < this.HEADER_SIZE) return null;
          var view = new DataView(bytes.buffer || bytes);
          
          if (view.getUint8(0) !== this.MAGIC[0] ||
              view.getUint8(1) !== this.MAGIC[1] ||
              view.getUint8(2) !== this.MAGIC[2] ||
              view.getUint8(3) !== this.MAGIC[3]) {
            return null;
          }
          
          var type = view.getUint32(8, false);
          var length = view.getUint32(12, false);
          var payload = bytes.slice(this.HEADER_SIZE, this.HEADER_SIZE + length);
          
          if (type === this.TYPES.JSON) {
            var json = new TextDecoder().decode(payload);
            return JSON.parse(json);
          }
          
          return { type: type, payload: payload };
        },
        
        toBase64: function(bytes) {
          return btoa(String.fromCharCode.apply(null, bytes));
        },
        
        fromBase64: function(b64) {
          var binary = atob(b64);
          var bytes = new Uint8Array(binary.length);
          for (var i = 0; i < binary.length; i++) {
            bytes[i] = binary.charCodeAt(i);
          }
          return bytes;
        }
      };
    })();
  ''';
}

class BinaryPacket {
  final int version;
  final int type;
  final Uint8List payload;

  const BinaryPacket({
    required this.version,
    required this.type,
    required this.payload,
  });
}
