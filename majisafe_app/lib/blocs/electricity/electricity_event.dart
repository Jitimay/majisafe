import 'package:equatable/equatable.dart';

abstract class ElectricityEvent extends Equatable {
  const ElectricityEvent();
  @override
  List<Object?> get props => [];
}

class ElectricityBuyPressed extends ElectricityEvent {
  const ElectricityBuyPressed({required this.meterNumber, required this.coins});
  final String meterNumber;
  final double coins;
  @override
  List<Object?> get props => [meterNumber, coins];
}

class ElectricityReset extends ElectricityEvent {
  const ElectricityReset();
}
