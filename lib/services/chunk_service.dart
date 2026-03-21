import 'dart:typed_data';

/// A single chunk in a chunked BLE transfer.
///
/// Wire format: `[seq_hi, seq_lo, total_hi, total_lo, ...payload]`
///
/// This is a direct port of the Rust `Chunk` struct.
class Chunk {
  final int sequence;
  final int total;
  final Uint8List payload;

  const Chunk({
    required this.sequence,
    required this.total,
    required this.payload,
  });

  /// Serialize to wire bytes: 4-byte header (sequence BE u16 + total BE u16)
  /// followed by payload.
  Uint8List toBytes() {
    final buf = ByteData(4 + payload.length);
    buf.setUint16(0, sequence, Endian.big);
    buf.setUint16(2, total, Endian.big);
    final result = buf.buffer.asUint8List();
    result.setRange(4, 4 + payload.length, payload);
    return result;
  }

  /// Parse a chunk from wire bytes.
  factory Chunk.fromBytes(Uint8List data) {
    if (data.length < 4) {
      throw ArgumentError(
        'chunk data too short: need at least 4 bytes, got ${data.length}',
      );
    }
    final view = ByteData.sublistView(data);
    final sequence = view.getUint16(0, Endian.big);
    final total = view.getUint16(2, Endian.big);
    final payload = Uint8List.sublistView(data, 4);
    return Chunk(sequence: sequence, total: total, payload: payload);
  }
}

/// Splits large payloads into MTU-sized [Chunk]s and reassembles them.
///
/// This is a direct port of the Rust `ChunkProtocol`.
class ChunkProtocol {
  final int mtu;

  const ChunkProtocol({required this.mtu});

  /// Maximum payload bytes per chunk after the 4-byte header.
  int get _maxPayload => (mtu - 4).clamp(0, mtu);

  /// Split [data] into a sequence of [Chunk]s.
  List<Chunk> chunkData(Uint8List data) {
    final maxPayload = _maxPayload;

    if (maxPayload <= 0) {
      // Degenerate MTU -- pack everything into one oversized chunk.
      return [Chunk(sequence: 0, total: 1, payload: data)];
    }

    if (data.isEmpty) {
      return [Chunk(sequence: 0, total: 1, payload: Uint8List(0))];
    }

    final chunksNeeded = (data.length + maxPayload - 1) ~/ maxPayload;
    final total = chunksNeeded;

    return List.generate(chunksNeeded, (i) {
      final start = i * maxPayload;
      final end =
          (start + maxPayload > data.length) ? data.length : start + maxPayload;
      return Chunk(
        sequence: i,
        total: total,
        payload: Uint8List.sublistView(data, start, end),
      );
    });
  }

  /// Reassemble a set of [Chunk]s back into the original data.
  ///
  /// Chunks are sorted by `sequence` before concatenation.
  static Uint8List reassemble(List<Chunk> chunks) {
    if (chunks.isEmpty) {
      throw ArgumentError('no chunks to reassemble');
    }

    final expectedTotal = chunks.first.total;
    if (chunks.length != expectedTotal) {
      throw ArgumentError(
        'expected $expectedTotal chunks but got ${chunks.length}',
      );
    }

    final sorted = List<Chunk>.from(chunks)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    // Verify consistency.
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i].total != expectedTotal) {
        throw ArgumentError(
          'chunk $i has total=${sorted[i].total} but expected $expectedTotal',
        );
      }
      if (sorted[i].sequence != i) {
        throw ArgumentError(
          'expected sequence $i but got ${sorted[i].sequence}',
        );
      }
    }

    final totalLength =
        sorted.fold<int>(0, (sum, chunk) => sum + chunk.payload.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in sorted) {
      result.setRange(offset, offset + chunk.payload.length, chunk.payload);
      offset += chunk.payload.length;
    }
    return result;
  }
}
