enum WorkspaceFilter {
  all,
  selected,
  laa,
  nonLaa,
  invalid,
}

enum EntrySortField {
  path,
  current,
  result,
}

enum LaaAction {
  enable,
  disable,
}

enum ProbeState {
  ready,
  missing,
  invalidPe,
  readError,
}

enum BusyState {
  idle,
  scanning,
  applying,
}

class ExecutableEntry {
  ExecutableEntry({
    required this.path,
    required this.probeState,
    this.currentLaa,
    this.characteristics,
    this.has32BitMachineFlag,
    this.problem = '',
    this.lastResult = '',
    this.isChecked = false,
  });

  final String path;
  bool? currentLaa;
  int? characteristics;
  bool? has32BitMachineFlag;
  ProbeState probeState;
  String problem;
  String lastResult;
  bool isChecked;

  bool get isReady => probeState == ProbeState.ready && currentLaa != null;

  String get currentLabel {
    if (!isReady) {
      return 'Unavailable';
    }

    return currentLaa! ? 'On' : 'Off';
  }

  String get statusLabel {
    if (lastResult.isNotEmpty) {
      return lastResult;
    }

    switch (probeState) {
      case ProbeState.ready:
        return 'Ready';
      case ProbeState.missing:
        return 'Missing';
      case ProbeState.invalidPe:
        return 'Invalid PE';
      case ProbeState.readError:
        return 'Read Error';
    }
  }
}

extension WorkspaceFilterLabel on WorkspaceFilter {
  String get label {
    switch (this) {
      case WorkspaceFilter.all:
        return 'All';
      case WorkspaceFilter.selected:
        return 'Selected';
      case WorkspaceFilter.laa:
        return 'LAA';
      case WorkspaceFilter.nonLaa:
        return 'Non-LAA';
      case WorkspaceFilter.invalid:
        return 'Invalid';
    }
  }
}