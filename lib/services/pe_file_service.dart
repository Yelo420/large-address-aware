import 'dart:io';
import 'dart:typed_data';

import '../models/workspace_models.dart';

class PeProbeResult {
  const PeProbeResult({
    required this.state,
    required this.message,
    this.largeAddressAware,
    this.characteristics,
    this.characteristicsOffset,
    this.has32BitMachineFlag,
  });

  final ProbeState state;
  final String message;
  final bool? largeAddressAware;
  final int? characteristics;
  final int? characteristicsOffset;
  final bool? has32BitMachineFlag;
}

class PePatchResult {
  const PePatchResult({
    required this.success,
    required this.message,
    this.probe,
  });

  final bool success;
  final String message;
  final PeProbeResult? probe;
}

class PeFileService {
  static const int imageFileLargeAddressAware = 0x0020;
  static const int imageFile32BitMachine = 0x0100;

  Future<PeProbeResult> inspect(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return const PeProbeResult(
        state: ProbeState.missing,
        message: 'The file no longer exists.',
      );
    }

    try {
      final bytes = await file.readAsBytes();
      return _probeBytes(bytes);
    } on FileSystemException catch (error) {
      return PeProbeResult(
        state: ProbeState.readError,
        message: error.message,
      );
    } catch (_) {
      return const PeProbeResult(
        state: ProbeState.readError,
        message: 'The executable could not be read.',
      );
    }
  }

  Future<PePatchResult> setLargeAddressAware(String path, bool enabled) async {
    final file = File(path);
    if (!await file.exists()) {
      return const PePatchResult(
        success: false,
        message: 'The file no longer exists.',
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final probe = _probeBytes(bytes);
      if (probe.state != ProbeState.ready ||
          probe.characteristicsOffset == null ||
          probe.characteristics == null) {
        return PePatchResult(
          success: false,
          message: probe.message,
          probe: probe,
        );
      }

      var nextValue = probe.characteristics!;
      if (enabled) {
        nextValue |= imageFileLargeAddressAware;
      } else {
        nextValue &= ~imageFileLargeAddressAware;
      }

      final patched = Uint8List.fromList(bytes);
      final data = ByteData.sublistView(patched);
      data.setUint16(
        probe.characteristicsOffset!,
        nextValue & 0xFFFF,
        Endian.little,
      );

      await file.writeAsBytes(patched, flush: true);

      final updatedProbe = await inspect(path);
      return PePatchResult(
        success: true,
        message: 'Updated.',
        probe: updatedProbe,
      );
    } on FileSystemException catch (error) {
      return PePatchResult(
        success: false,
        message: error.message,
      );
    } catch (_) {
      return const PePatchResult(
        success: false,
        message: 'The executable could not be updated.',
      );
    }
  }

  PeProbeResult _probeBytes(Uint8List bytes) {
    if (bytes.length < 64) {
      return const PeProbeResult(
        state: ProbeState.invalidPe,
        message: 'The file is too small to contain a PE header.',
      );
    }

    if (bytes[0] != 0x4D || bytes[1] != 0x5A) {
      return const PeProbeResult(
        state: ProbeState.invalidPe,
        message: 'The file does not start with an MZ header.',
      );
    }

    final data = ByteData.sublistView(bytes);
    final peHeaderOffset = data.getUint32(60, Endian.little);
    final characteristicsOffset = peHeaderOffset + 22;

    if (characteristicsOffset + 2 > bytes.length) {
      return const PeProbeResult(
        state: ProbeState.invalidPe,
        message: 'The PE header points outside the file.',
      );
    }

    if (bytes[peHeaderOffset] != 0x50 || bytes[peHeaderOffset + 1] != 0x45) {
      return const PeProbeResult(
        state: ProbeState.invalidPe,
        message: 'The file does not contain a PE signature.',
      );
    }

    final characteristics = data.getUint16(characteristicsOffset, Endian.little);
    final laa = (characteristics & imageFileLargeAddressAware) ==
        imageFileLargeAddressAware;
    final has32BitFlag =
        (characteristics & imageFile32BitMachine) == imageFile32BitMachine;

    return PeProbeResult(
      state: ProbeState.ready,
      message: 'Ready',
      characteristics: characteristics,
      characteristicsOffset: characteristicsOffset,
      largeAddressAware: laa,
      has32BitMachineFlag: has32BitFlag,
    );
  }
}