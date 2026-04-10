import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:majisafe_app/blocs/electricity/electricity_event.dart';
import 'package:majisafe_app/blocs/electricity/electricity_state.dart';
import 'package:majisafe_app/repositories/electricity_repository.dart';

class ElectricityBloc extends Bloc<ElectricityEvent, ElectricityState> {
  ElectricityBloc({required ElectricityRepository repository})
      : _repo = repository,
        super(const ElectricityInitial()) {
    on<ElectricityBuyPressed>(_onBuy);
    on<ElectricityReset>((_, emit) => emit(const ElectricityInitial()));
  }

  final ElectricityRepository _repo;

  Future<void> _onBuy(ElectricityBuyPressed event, Emitter<ElectricityState> emit) async {
    emit(const ElectricityLoading());
    try {
      final order = await _repo.buy(
        meterNumber: event.meterNumber,
        coins: event.coins,
      );
      emit(ElectricitySuccess(order));
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map && body['message'] is String) {
        emit(ElectricityFailure(body['message'] as String));
      } else {
        emit(ElectricityFailure(e.message ?? 'Purchase failed'));
      }
    } catch (e) {
      emit(ElectricityFailure(e.toString()));
    }
  }
}
