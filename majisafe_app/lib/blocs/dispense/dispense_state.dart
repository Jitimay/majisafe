import 'package:equatable/equatable.dart';
import 'package:majisafe_app/models/station.dart';

/// Dispense UI state machine.
abstract class DispenseState extends Equatable {
  const DispenseState();

  @override
  List<Object?> get props => [];
}

class DispenseInitial extends DispenseState {
  const DispenseInitial();
}

class DispenseSelecting extends DispenseState {
  const DispenseSelecting({
    required this.station,
    this.litres = 5,
  });

  final Station station;
  final double litres;

  @override
  List<Object?> get props => [station, litres];
}

/// Waiting for POST /dispense/request to return a transaction id.
class DispenseRequesting extends DispenseState {
  const DispenseRequesting({required this.station, required this.litres});

  final Station station;
  final double litres;

  @override
  List<Object?> get props => [station, litres];
}

class DispenseInProgress extends DispenseState {
  const DispenseInProgress({
    required this.station,
    required this.requestedLitres,
    required this.txId,
    this.progressLitres,
  });

  final Station station;
  final double requestedLitres;
  final String txId;
  final double? progressLitres;

  @override
  List<Object?> get props => [station, requestedLitres, txId, progressLitres];
}

class DispenseSuccess extends DispenseState {
  const DispenseSuccess({
    required this.txId,
    required this.actualLitres,
    required this.coinsUsed,
  });

  final String txId;
  final double actualLitres;
  final double coinsUsed;

  @override
  List<Object?> get props => [txId, actualLitres, coinsUsed];
}

class DispenseFailure extends DispenseState {
  const DispenseFailure(this.message, {this.refunded = false});

  final String message;
  final bool refunded;

  @override
  List<Object?> get props => [message, refunded];
}
