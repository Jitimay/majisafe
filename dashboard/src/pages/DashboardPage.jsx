import React, { useState, useEffect } from 'react';
import { useStations } from '../hooks/useStations.js';
import StationList from '../components/StationList.jsx';
import Header from '../components/Header.jsx';

function StatCard({ icon, label, value, sub, color = 'emerald' }) {
  const colors = {
    emerald: 'from-emerald-500/20 to-emerald-600/10 border-emerald-500/20 text-emerald-400',
    sky:     'from-sky-500/20 to-sky-600/10 border-sky-500/20 text-sky-400',
    amber:   'from-amber-500/20 to-amber-600/10 border-amber-500/20 text-amber-400',
    red:     'from-red-500/20 to-red-600/10 border-red-500/20 text-red-400',
  };
  return (
    <div className={`glass-card p-5 bg-gradient-to-br ${colors[color]}`}>
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">{label}</p>
          <p className="text-3xl font-black text-white mt-1">{value}</p>
          {sub && <p className="text-xs text-slate-500 mt-1">{sub}</p>}
        </div>
        <div className={`text-2xl`}>{icon}</div>
      </div>
    </div>
  );
}

export default function DashboardPage() {
  const { data, isFetching, isError, error } = useStations();
  const [toast, setToast] = useState(null);

  useEffect(() => {
    if (isError) setToast('Connection lost — retrying…');
    else setToast(null);
  }, [isError]);

  const stations = data?.stations ?? [];
  const online = stations.filter(s => s.status === 'online' || s.status === 'dispensing').length;
  const offline = stations.filter(s => s.status === 'offline').length;
  const lowTank = stations.filter(s => (s.tank_level ?? 100) < 30).length;
  const avgTank = stations.length
    ? Math.round(stations.reduce((a, s) => a + (s.tank_level ?? 100), 0) / stations.length)
    : 0;

  return (
    <div className="min-h-screen">
      <Header isFetching={isFetching} />

      {/* Toast */}
      {toast && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 flex items-center gap-2 bg-slate-800 border border-slate-700 text-white text-sm px-5 py-3 rounded-2xl shadow-2xl">
          <svg className="animate-spin w-4 h-4 text-amber-400" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/>
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
          </svg>
          {toast}
        </div>
      )}

      <main className="max-w-7xl mx-auto px-4 sm:px-6 py-8 space-y-8">
        {/* Hero */}
        <div>
          <h1 className="text-2xl font-black text-white">Water Distribution</h1>
          <p className="text-slate-500 text-sm mt-1">Real-time monitoring and pump control for all stations</p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard icon="🏭" label="Total Stations" value={stations.length} color="sky" />
          <StatCard icon="✅" label="Online" value={online} sub={`${stations.length - online} inactive`} color="emerald" />
          <StatCard icon="💧" label="Avg Tank Level" value={`${avgTank}%`} color="sky" />
          <StatCard icon="⚠️" label="Low Tank" value={lowTank} sub="Below 30%" color={lowTank > 0 ? 'red' : 'emerald'} />
        </div>

        {/* Station list */}
        <div>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-base font-bold text-white">
              Stations
              {stations.length > 0 && (
                <span className="ml-2 text-sm font-normal text-slate-500">({stations.length})</span>
              )}
            </h2>
            <div className="flex items-center gap-1.5 text-xs text-slate-500">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
              Auto-refresh 30s
            </div>
          </div>

          {isError && stations.length === 0 ? (
            <div className="glass-card p-12 text-center">
              <div className="text-4xl mb-3">📡</div>
              <p className="text-slate-400 text-sm">{error?.message || 'Failed to load stations.'}</p>
            </div>
          ) : (
            <StationList stations={stations} />
          )}
        </div>
      </main>
    </div>
  );
}
