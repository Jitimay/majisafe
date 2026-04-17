import React, { useState } from 'react';

function formatRuntime(hours) {
  const total = Math.round((hours ?? 0) * 60);
  const h = Math.floor(total / 60);
  const m = total % 60;
  return `${h}h ${m}m`;
}

export default function PumpCard({ stationId, pumpNumber, isActive, runtimeHours, onToggle }) {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState(null);

  async function handleToggle() {
    const action = isActive ? 'deactivate' : 'activate';
    setPending(true);
    setError(null);
    try {
      await onToggle(action);
    } catch (err) {
      setError(err?.response?.data?.message || 'Command failed. Try again.');
    } finally {
      setPending(false);
    }
  }

  return (
    <div className={`glass-card p-5 flex flex-col gap-4 transition-all duration-300 ${
      isActive ? 'border-emerald-500/40 bg-emerald-950/30' : ''
    }`}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className={`relative w-10 h-10 rounded-xl flex items-center justify-center transition-all duration-300 ${
            isActive
              ? 'bg-emerald-500/20 border border-emerald-500/40'
              : 'bg-slate-800 border border-slate-700'
          }`}>
            {isActive && (
              <span className="absolute inset-0 rounded-xl border border-emerald-400/30 animate-ping" />
            )}
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke={isActive ? '#10b981' : '#64748b'} strokeWidth="2">
              <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
            </svg>
          </div>
          <div>
            <p className="font-bold text-white text-sm">Pump {pumpNumber}</p>
            <p className="text-xs text-slate-500">Relay {pumpNumber}</p>
          </div>
        </div>
        <span className={`px-3 py-1 rounded-full text-xs font-bold tracking-wide ${
          isActive
            ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
            : 'bg-slate-800 text-slate-500 border border-slate-700'
        }`}>
          {isActive ? '● ON' : '○ OFF'}
        </span>
      </div>

      {/* Runtime */}
      <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-slate-800/50 border border-slate-700/50">
        <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="#64748b" strokeWidth="2">
          <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
        </svg>
        <span className="text-xs text-slate-500">Runtime</span>
        <span className="text-xs font-bold text-slate-300 ml-auto">{formatRuntime(runtimeHours)}</span>
      </div>

      {/* Toggle */}
      <button
        onClick={handleToggle}
        disabled={pending}
        className={`min-h-[44px] w-full rounded-xl text-sm font-bold transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-slate-900 active:scale-95 ${
          pending
            ? 'bg-slate-800 text-slate-500 cursor-not-allowed'
            : isActive
            ? 'bg-red-500/10 text-red-400 hover:bg-red-500/20 border border-red-500/30 focus:ring-red-500'
            : 'bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20 border border-emerald-500/30 focus:ring-emerald-500'
        }`}
      >
        {pending ? (
          <span className="flex items-center justify-center gap-2">
            <svg className="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
            </svg>
            Sending…
          </span>
        ) : isActive ? '⏹ Turn OFF' : '▶ Turn ON'}
      </button>

      {error && (
        <p className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2">{error}</p>
      )}
    </div>
  );
}
