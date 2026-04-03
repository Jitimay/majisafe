import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:majisafe_app/blocs/dispense/dispense_event.dart';
import 'package:majisafe_app/blocs/dispense/dispense_state.dart';
import 'package:majisafe_app/repositories/dispense_repository.dart';

/// Orchestrates station selection, request, and status polling.
class DispenseBloc extends Bloc<DispenseEvent, DispenseState> {
  DispenseBloc({required DispenseRepository repository})
      : _repo = repository,
        super(const DispenseInitial()) {
    on<DispenseStationSelected>(_onStation);
    on<DispenseLitresChanged>(_onLitres);
    on<DispenseConfirmPressed>(_onConfirm);
    on<DispensePollTick>(_onPoll);
    on<DispenseReset>((_, emit) => emit(const DispenseInitial()));
  }

  final DispenseRepository _repo;

  void _onStation(DispenseStationSelected event, Emitter<DispenseState> emit) {
    emit(DispenseSelecting(station: event.station, litres: 5));
  }

  void _onLitres(DispenseLitresChanged event, Emitter<DispenseState> emit) {
    final s = state;
    if (s is DispenseSelecting) {
      emit(DispenseSelecting(station: s.station, litres: event.litres));
    }
  }

  Future<void> _onConfirm(DispenseConfirmPressed event, Emitter<DispenseState> emit) async {
    final s = state;
    if (s is! DispenseSelecting) return;
    emit(DispenseRequesting(station: s.station, litres: s.litres));
    try {
      final data = await _repo.requestDispense(
        stationId: s.station.id,
        litres: s.litres,
      );
      final txId = data['tx_id'] as String?;
      if (txId == null || txId.isEmpty) {
        emit(const DispenseFailure('Invalid server response'));
        return;
      }
      emit(
        DispenseInProgress(
          station: s.station,
          requestedLitres: s.litres,
          txId: txId,
        ),
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map && body['message'] is String) {
        emit(DispenseFailure(body['message'] as String));
      } else {
        emit(DispenseFailure(e.message ?? 'Request failed'));
      }
    } catch (e) {
      emit(DispenseFailure(e.toString()));
    }
  }

  Future<void> _onPoll(DispensePollTick event, Emitter<DispenseState> emit) async {
    final s = state;
    if (s is! DispenseInProgress) return;
    try {
      final data = await _repo.dispenseStatus(event.txId);
      final status = data['status'] as String? ?? '';
      final progress = data['progress_litres'];
      final progressVal = progress == null ? null : (progress as num).toDouble();
      if (status == 'pending') {
        emit(
          DispenseInProgress(
            station: s.station,
            requestedLitres: s.requestedLitres,
            txId: s.txId,
            progressLitres: progressVal,
          ),
        );
        return;
      }
      if (status == 'confirmed') {
        final actual = (data['actual_litres'] as num?)?.toDouble() ?? s.requestedLitres;
        final coins = (data['requested_litres'] as num?)?.toDouble() ?? s.requestedLitres;
        emit(
          DispenseSuccess(
            txId: event.txId,
            actualLitres: actual,
            coinsUsed: coins,
          ),
        );
        return;
      }
      if (status == 'refunded' || status == 'failed') {
        emit(
          DispenseFailure(
            status == 'refunded' ? 'Dispense aborted; coins refunded.' : 'Dispense failed.',
            refunded: status == 'refunded',
          ),
        );
        return;
      }
      emit(DispenseFailure('Unknown status: $status'));
    } on DioException catch (e) {
      emit(DispenseFailure(e.message ?? 'Poll failed'));
    } catch (e) {
      emit(DispenseFailure(e.toString()));
    }
  }
}
