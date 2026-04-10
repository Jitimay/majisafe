import 'package:equatable/equatable.dart';
import 'package:majisafe_app/models/electricity_order.dart';

abstract class ElectricityState extends Equatable {
  const ElectricityState();
  @override
  List<Object?> get props => [];
}

class ElectricityInitial extends ElectricityState {
  const ElectricityInitial();
}

class ElectricityLoading extends ElectricityState {
  const ElectricityLoading();
}

class ElectricitySuccess extends ElectricityState {
  const ElectricitySuccess(this.order);
  final ElectricityOrder order;
  @override
  List<Object?> get props => [order];
}

class ElectricityFailure extends ElectricityState {
  const ElectricityFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
