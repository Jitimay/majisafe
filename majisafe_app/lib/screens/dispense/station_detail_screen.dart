import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/blocs/dispense/dispense_bloc.dart';
import 'package:majisafe_app/blocs/dispense/dispense_event.dart';
import 'package:majisafe_app/models/station.dart';
import 'package:majisafe_app/widgets/station_status_badge.dart';

/// Station info and entry into the dispense flow.
class StationDetailScreen extends StatelessWidget {
  const StationDetailScreen({super.key, required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final tank = station.tankLevel ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(station.name ?? station.id)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              StationStatusBadge(status: station.status),
              const SizedBox(width: 12),
              Text(station.id, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Text(station.location ?? '—', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          Text('Tank level', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (tank / 100).clamp(0, 1)),
          const SizedBox(height: 8),
          Text('${tank.toStringAsFixed(0)} %'),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: station.status == 'offline' || station.status == 'error'
                ? null
                : () {
                    context.read<DispenseBloc>().add(DispenseStationSelected(station));
                    context.push('/dispense/run');
                  },
            icon: const Icon(Icons.water_drop),
            label: const Text('Dispense water'),
          ),
        ],
      ),
    );
  }
}
