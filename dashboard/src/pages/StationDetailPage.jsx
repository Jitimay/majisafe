import React, { useState } from 'react';
import { useParams } from 'react-router-dom';
import { useStations } from '../hooks/useStations.js';
import { usePumpStatus, usePumpCommand } from '../hooks/usePumpStatus.js';
import { useRecommendation } from '../hooks/useRecommendation.js';
import { useDailyUsage, useHourlyHeatmap } from '../hooks/useAnalytics.js';
import TankGauge from '../components/TankGauge.jsx';
import PumpCard from '../components/PumpCard.jsx';
import RecommendationPanel from '../components/RecommendationPanel.jsx';
import DailyChart from '../components/DailyChart.jsx';
import HeatmapGrid from '../components/HeatmapGrid.jsx';
import Header from '../components/Header.jsx';

function StatusBadge({ status }) {
  const map = {
    online:     { cls: 'badge-online',     dot: 'bg-emerald-400', label: 'Online' },
    dispensing: { cls: 'badge-dispensing', dot: 'bg-sky-400 animate-pulse', label: 'Dispensing' },
    error:      { cls: 'badge-error',      dot: 'bg-red-400',     label: 'Error' },
    offline:    { cls: 'badge-offline',    dot: 'bg-slate-500',   label: 'Offline' },
  };
  const s = map[status] || map.offline;
  return (
    <span className={`inline-flex items-center gap-1.5 ${s.cls}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${s.dot}`} />
      {s.label}
    </span>
  );
}

function SectionTitle({ children }) {
  return (
    <h3 className="text-xs font-bold text-slate-500 uppercase tracking-widest mb-3">{children}</h3>
  );
}

export default function StationDetailPage() {
  const { id } = useParams();
  const [toast, setToast] = useState(null);

  const { data: stationsData, isFetching } = useStations();
  const station = stationsData?.stations?.find((s) => s.id === id);

  const { data: pumpData } = usePumpStatus(id);
  const pumpMutation = usePumpCommand(id);
  const { data: recData } = useRecommendation(id);
  const { data: dailyData } = useDailyUsage(id, 7);
  const { data: heatmapData } = useHourlyHeatmap(id);

  const pump1Active = pumpData?.pump_1_active ?? station?.pump_1_active ?? false;
  const pump2Active = pumpData?.pump_2_active ?? station?.pump_2_active ?? false;
  const pump1Hours  = pumpData?.pump_1_runtime_hours ?? station?.pump_1_runtime_hours ?? 0;
  const pump2Hours  = pumpData?.pump_2_runtime_hours ?? station?.pump_2_runtime_hours ?? 0;

  async function handlePumpToggle(pumpNumber, action) {
    try {
      await pumpMutation.mutateAsync({ pump_number: pumpNumber, action });
    } catch (err) {
      setToast('Pump command failed. Please try again.');
      setTimeout(() => setToast(null), 4000);
      throw err;
    }
  }

  return (
    <div className="min-h-screen">
      <Header showBack title={station?.name || id} isFetching={isFetching} />

      {/* Toast */}
      {toast && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 flex items-center gap-2 bg-red-900/80 border border-red-500/30 text-red-200 text-sm px-5 py-3 rounded-2xl shadow-2xl backdrop-blur-xl">
          <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
          </svg>
          {toast}
        </div>
      )}

      <main className="max-w-7xl mx-auto px-4 sm:px-6 py-8 space-y-8">
        {/* Station hero */}
        {station && (
          <div className="glass-card p-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div className="flex items-center gap-4">
                <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-500/20 to-emerald-600/10 border border-emerald-500/20 flex items-center justify-center">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                    <path d="M12 2C12 2 5 9.5 5 14a7 7 0 0014 0C19 9.5 12 2 12 2z" fill="#10b981"/>
                  </svg>
                </div>
                <div>
                  <h1 className="text-xl font-black text-white">{station.name || station.id}</h1>
                  <p className="text-sm text-slate-500">{station.location} · <span className="font-mono text-slate-400">{station.id}</span></p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <StatusBadge status={station.status} />
                {station.last_seen && (
                  <span className="text-xs text-slate-600">
                    Last seen {new Date(station.last_seen).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </span>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Tank + Pumps */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Tank gauge */}
          <div className="glass-card p-6 flex flex-col items-center gap-4">
            <SectionTitle>Tank Level</SectionTitle>
            <TankGauge
              level={station?.tank_level ?? 0}
              isOffline={station?.status === 'offline'}
              size={180}
            />
            {station && station.status !== 'offline' && (
              <div className="w-full space-y-2">
                <div className="flex justify-between text-xs text-slate-500">
                  <span>Capacity</span>
                  <span className="font-semibold text-slate-300">5,000 L</span>
                </div>
                <div className="flex justify-between text-xs text-slate-500">
                  <span>Available</span>
                  <span className="font-semibold text-emerald-400">
                    {Math.round((station.tank_level ?? 0) / 100 * 5000).toLocaleString()} L
                  </span>
                </div>
              </div>
            )}
          </div>

          {/* Pump cards */}
          <div className="lg:col-span-2 space-y-4">
            <SectionTitle>Pump Control</SectionTitle>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <PumpCard
                stationId={id}
                pumpNumber={1}
                isActive={pump1Active}
                runtimeHours={pump1Hours}
                onToggle={(action) => handlePumpToggle(1, action)}
              />
              <PumpCard
                stationId={id}
                pumpNumber={2}
                isActive={pump2Active}
                runtimeHours={pump2Hours}
                onToggle={(action) => handlePumpToggle(2, action)}
              />
            </div>
          </div>
        </div>

        {/* AI Recommendation */}
        <div>
          <SectionTitle>AI Recommendation</SectionTitle>
          <RecommendationPanel
            stationId={id}
            recommendation={recData?.recommendation}
          />
        </div>

        {/* Charts */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="glass-card p-6">
            <SectionTitle>Daily Usage — Last 7 Days</SectionTitle>
            <DailyChart data={dailyData?.data} />
          </div>
          <div className="glass-card p-6">
            <SectionTitle>Hourly Demand Heatmap</SectionTitle>
            <HeatmapGrid matrix={heatmapData?.matrix} />
          </div>
        </div>
      </main>
    </div>
  );
}
