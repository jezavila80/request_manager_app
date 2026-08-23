enum TriState {
  sinDefinir,
  noAplica,
  conValor,
}

class TriStateValue<T> {
  final TriState state;
  final T? value;

  const TriStateValue._(this.state, this.value);

  // Factories
  const TriStateValue.sinDefinir() : this._(TriState.sinDefinir, null);
  const TriStateValue.noAplica() : this._(TriState.noAplica, null);

  factory TriStateValue.conValor(T value) {
    if (value is String && value.trim().isEmpty) {
      throw ArgumentError(
          'El valor no puede estar compuesto únicamente por espacios en blanco.');
    }
    return TriStateValue._(TriState.conValor, value);
  }

  bool get isSinDefinir => state == TriState.sinDefinir;
  bool get isNoAplica => state == TriState.noAplica;
  bool get isConValor => state == TriState.conValor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TriStateValue<T> &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          value == other.value;

  @override
  int get hashCode => state.hashCode ^ value.hashCode;

  @override
  String toString() {
    switch (state) {
      case TriState.sinDefinir:
        return 'SIN DEFINIR';
      case TriState.noAplica:
        return 'NO APLICA';
      case TriState.conValor:
        return value.toString();
    }
  }
}
