import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:majisafe_app/models/station.dart';
import 'package:majisafe_app/repositories/station_repository.dart';
import 'package:majisafe_app/widgets/station_status_badge.dart';

/// Lists stations with search and tank level bar.
class StationListScreen extends StatefulWidget {
  const StationListScreen({super.key});

  @override
  State<StationListScreen> createState() => _StationListScreenState();
}

class _StationListScreenState extends State<StationListScreen> {
  final _search = TextEditingController();
  List<Station> _all = [];
  bool _loading = true;
  String? _error;
  DateTime? _cacheAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<StationRepository>();
      final list = await repo.listStations();
      final ts = await repo.cacheTimestamp();
      if (mounted) {
        setState(() {
          _all = list;
          _cacheAt = ts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _all
        : _all
            .where(
              (s) =>
                  s.id.toLowerCase().contains(q) ||
                  (s.name ?? '').toLowerCase().contains(q) ||
                  (s.location ?? '').toLowerCase().contains(q),
            )
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Stations')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search name or ID',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_cacheAt != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'List cached · ${_cacheAt!.toLocal()}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final s = filtered[i];
                            final tank = s.tankLevel ?? 0;
                            return ListTile(
                              title: Text(s.name ?? s.id),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.location ?? ''),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(value: (tank / 100).clamp(0, 1)),
                                ],
                              ),
                              trailing: StationStatusBadge(status: s.status),
                              onTap: () => context.push('/dispense/detail', extra: s),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
