import 'package:equatable/equatable.dart';
import 'package:majisafe_app/models/station.dart';

/// Dispense flow actions.
abstract class DispenseEvent extends Equatable {
  const DispenseEvent();

  @override
  List<Object?> get props => [];
}

/// User picked a station.
class DispenseStationSelected extends DispenseEvent {
  const DispenseStationSelected(this.station);

  final Station station;

  @override
  List<Object?> get props => [station];
}

/// Updates desired litres (slider / field).
class DispenseLitresChanged extends DispenseEvent {
  const DispenseLitresChanged(this.litres);

  final double litres;

  @override
  List<Object?> get props => [litres];
}

/// Calls POST /dispense/request.
class DispenseConfirmPressed extends DispenseEvent {
  const DispenseConfirmPressed();
}

/// Polls GET /dispense/status/:txId until terminal state.
class DispensePollTick extends DispenseEvent {
  const DispensePollTick(this.txId);

  final String txId;

  @override
  List<Object?> get props => [txId];
}

/// Resets wizard for another dispense.
class DispenseReset extends DispenseEvent {
  const DispenseReset();
}
