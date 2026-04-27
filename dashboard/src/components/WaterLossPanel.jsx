import React, { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import client from '../api/client.js';

async function fetchWaterLoss(stationId, hours) {
  const { data } = await client.get(`/api/analytics/${stationId}/water-loss?hours=${hours}`);
  return data;
}

async function injectLoss(stationId, lossLitres) {
  const { data } = await client.post('/api/simulate/water-loss', {
    station_id: stationId,
    loss_litres: lossLitres,
  });
  return data;
}

const severityConfig = {
  normal:   { bg: 'bg-emerald-950/40 border-emerald-500/20', bar: 'bg-emerald-500', text: 'text-emerald-400', label: 'Normal', icon: '✓' },
  low:      { bg: 'bg-sky-950/40 border-sky-500/20',         bar: 'bg-sky-400',     text: 'text-sky-400',     label: 'Low',    icon: 'ℹ' },
  warning:  { bg: 'bg-amber-950/40 border-amber-500/20',     bar: 'bg-amber-500',   text: 'text-amber-400',   label: 'Warning', icon: '⚠' },
  critical: { bg: 'bg-red-950/40 border-red-500/20',         bar: 'bg-red-500',     text: 'text-red-400',     label: 'Critical', icon: '🚨' },
};

export default function WaterLossPanel({ stationId }) {
  const [hours, setHours] = useState(24);
  const [simLitres, setSimLitres] = useState(200);
  const [simPending, setSimPending] = useState(false);
  const [simResult, setSimResult] = useState(null);
  const queryClient = useQueryClient();

  const { data, isLoading, refetch } = useQuery({
    queryKey: ['waterLoss', stationId, hours],
    queryFn: () => fetchWaterLoss(stationId, hours),
    refetchInterval: 30_000,
  });

  async function handleSimulate() {
    setSimPending(true);
    setSimResult(null);
    try {
      const result = await injectLoss(stationId, simLitres);
      setSimResult(result);
      // Refresh loss data after injection
      setTimeout(() => {
        queryClient.invalidateQueries({ queryKey: ['waterLoss', stationId] });
        queryClient.invalidateQueries({ queryKey: ['stations'] });
        refetch();
      }, 500);
    } catch (e) {
      setSimResult({ error: e?.response?.data?.message || 'Simulation failed' });
    } finally {
      setSimPending(false);
    }
  }

  const cfg = severityConfig[data?.severity ?? 'normal'];

  return (
    <div className="space-y-4">
      {/* Detection card */}
      <div className={`glass-card p-5 border ${cfg.bg}`}>
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <span className="text-lg">{cfg.icon}</span>
            <span className={`text-sm font-bold ${cfg.text}`}>Water Loss Detection</span>
            <span className={`px-2 py-0.5 rounded-full text-xs font-bold border ${cfg.bg} ${cfg.text}`}>
              {cfg.label}
            </span>
          </div>
          {/* Time window selector */}
          <div className="flex gap-1">
            {[6, 24, 48, 168].map(h => (
              <button
                key={h}
                onClick={() => setHours(h)}
                className={`px-2.5 py-1 rounded-lg text-xs font-semibold transition-all ${
                  hours === h
                    ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                    : 'text-slate-500 hover:text-slate-300'
                }`}
              >
                {h < 24 ? `${h}h` : h === 168 ? '7d' : `${h/24}d`}
              </button>
            ))}
          </div>
        </div>

        {isLoading ? (
          <div className="space-y-2">
            <div className="h-4 bg-slate-700/50 rounded shimmer" />
            <div className="h-4 bg-slate-700/30 rounded w-3/4 shimmer" />
          </div>
        ) : data ? (
          <>
            <p className={`text-sm font-medium mb-4 ${cfg.text}`}>{data.message}</p>

            {/* Metrics grid */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-4">
              <Metric label="Pumped In" value={`${data.pumped_in_litres}L`} color="text-sky-400" />
              <Metric label="Dispensed" value={`${data.dispensed_litres}L`} color="text-emerald-400" />
              <Metric label="Tank Change" value={`${data.tank_change_litres > 0 ? '+' : ''}${data.tank_change_litres}L`} color="text-slate-300" />
              <Metric label="Unaccounted" value={`${data.loss_litres}L`} color={cfg.text} highlight />
            </div>

            {/* Loss bar */}
            <div>
              <div className="flex justify-between text-xs text-slate-500 mb-1.5">
                <span>Loss rate</span>
                <span className={`font-bold ${cfg.text}`}>{data.loss_percent}%</span>
              </div>
              <div className="h-2 bg-slate-800 rounded-full overflow-hidden">
                <div
                  className={`h-full rounded-full transition-all duration-700 ${cfg.bar}`}
                  style={{ width: `${Math.min(100, data.loss_percent)}%` }}
                />
              </div>
              <div className="flex justify-between text-xs text-slate-600 mt-1">
                <span>0% (no loss)</span>
                <span>5% low</span>
                <span>10% warning</span>
                <span>20%+ critical</span>
              </div>
            </div>

            {/* Tank levels */}
            <div className="flex gap-4 mt-4 pt-4 border-t border-white/5">
              <div className="text-xs text-slate-500">
                Tank start: <span className="text-slate-300 font-semibold">{data.tank_level_start}%</span>
              </div>
              <div className="text-xs text-slate-500">
                Tank now: <span className="text-slate-300 font-semibold">{data.tank_level_current}%</span>
              </div>
              <div className="text-xs text-slate-500">
                Window: <span className="text-slate-300 font-semibold">Last {hours < 24 ? `${hours}h` : hours === 168 ? '7 days' : `${hours/24} days`}</span>
              </div>
            </div>
          </>
        ) : null}
      </div>

      {/* Simulation panel */}
      <div className="glass-card p-5 border border-amber-500/20 bg-amber-950/20">
        <div className="flex items-center gap-2 mb-4">
          <span className="text-amber-400 text-sm">🧪</span>
          <span className="text-xs font-bold text-amber-400 uppercase tracking-wider">Simulate Water Loss</span>
          <span className="px-2 py-0.5 rounded-full text-xs font-bold bg-amber-500/20 text-amber-400 border border-amber-500/30">SANDBOX</span>
        </div>

        <p className="text-xs text-slate-500 mb-4">
          Inject a fake tank level drop to test the loss detection algorithm. This simulates a pipe leak or unauthorized tap.
        </p>

        <div className="flex items-center gap-3 flex-wrap">
          <div className="flex items-center gap-2">
            <span className="text-xs text-slate-400">Loss amount:</span>
            <div className="flex gap-1">
              {[50, 100, 200, 500, 1000].map(v => (
                <button
                  key={v}
                  onClick={() => setSimLitres(v)}
                  className={`px-2.5 py-1 rounded-lg text-xs font-semibold transition-all ${
                    simLitres === v
                      ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30'
                      : 'text-slate-500 hover:text-slate-300 border border-slate-700'
                  }`}
                >
                  {v}L
                </button>
              ))}
            </div>
          </div>

          <button
            onClick={handleSimulate}
            disabled={simPending}
            className="min-h-[36px] px-4 py-1.5 rounded-xl text-xs font-bold border transition-all duration-200 active:scale-95 bg-amber-500/10 text-amber-400 border-amber-500/30 hover:bg-amber-500/20 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {simPending ? 'Injecting...' : `⚡ Inject ${simLitres}L Loss`}
          </button>
        </div>

        {simResult && (
          <div className={`mt-3 px-4 py-3 rounded-xl text-xs border ${
            simResult.error
              ? 'bg-red-500/10 border-red-500/20 text-red-400'
              : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400'
          }`}>
            {simResult.error || simResult.message}
          </div>
        )}
      </div>
    </div>
  );
}

function Metric({ label, value, color, highlight }) {
  return (
    <div className={`px-3 py-2.5 rounded-xl ${highlight ? 'bg-white/5 border border-white/10' : 'bg-slate-800/40'}`}>
      <p className="text-xs text-slate-500 mb-1">{label}</p>
      <p className={`text-base font-black ${color}`}>{value}</p>
    </div>
  );
}
