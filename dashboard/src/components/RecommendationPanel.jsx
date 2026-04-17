import React, { useState } from 'react';
import * as pumpsApi from '../api/pumps.js';

const configs = {
  high: {
    bg: 'bg-red-950/40 border-red-500/30',
    icon: (
      <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="#f87171" strokeWidth="2">
        <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
        <line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
      </svg>
    ),
    label: 'text-red-400',
    btn: 'bg-red-500/20 text-red-300 hover:bg-red-500/30 border-red-500/30 focus:ring-red-500',
    badge: 'bg-red-500/20 text-red-400 border-red-500/30',
  },
  medium: {
    bg: 'bg-amber-950/40 border-amber-500/30',
    icon: (
      <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="#fbbf24" strokeWidth="2">
        <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
      </svg>
    ),
    label: 'text-amber-400',
    btn: 'bg-amber-500/20 text-amber-300 hover:bg-amber-500/30 border-amber-500/30 focus:ring-amber-500',
    badge: 'bg-amber-500/20 text-amber-400 border-amber-500/30',
  },
  low: {
    bg: 'bg-slate-800/40 border-slate-700/50',
    icon: (
      <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="#94a3b8" strokeWidth="2">
        <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
      </svg>
    ),
    label: 'text-slate-400',
    btn: 'bg-slate-700/50 text-slate-300 hover:bg-slate-700 border-slate-600 focus:ring-slate-500',
    badge: 'bg-slate-700/50 text-slate-400 border-slate-600',
  },
};

export default function RecommendationPanel({ stationId, recommendation }) {
  const [applying, setApplying] = useState(false);
  const [applyError, setApplyError] = useState(null);
  const [applied, setApplied] = useState(false);

  if (!recommendation) {
    return (
      <div className="glass-card p-5 shimmer">
        <div className="h-4 bg-slate-700/50 rounded w-3/4 mb-2" />
        <div className="h-3 bg-slate-700/30 rounded w-1/2" />
      </div>
    );
  }

  const { action, pump_number, reason, urgency } = recommendation;
  const cfg = configs[urgency] || configs.low;
  const showApply = action !== 'no_action';

  async function handleApply() {
    if (!pump_number) return;
    const cmd = action.startsWith('activate') ? 'activate' : 'deactivate';
    setApplying(true);
    setApplyError(null);
    try {
      await pumpsApi.sendCommand(stationId, { pump_number, action: cmd });
      setApplied(true);
      setTimeout(() => setApplied(false), 4000);
    } catch (err) {
      setApplyError(err?.response?.data?.message || 'Failed to apply.');
    } finally {
      setApplying(false);
    }
  }

  return (
    <div className={`glass-card p-5 border ${cfg.bg} space-y-4`}>
      <div className="flex items-start gap-3">
        <div className="shrink-0 mt-0.5">{cfg.icon}</div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1.5">
            <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">AI Recommendation</span>
            <span className={`px-2 py-0.5 rounded-full text-xs font-semibold border ${cfg.badge} capitalize`}>
              {urgency}
            </span>
          </div>
          <p className={`text-sm font-semibold leading-relaxed ${cfg.label}`}>{reason}</p>
        </div>
      </div>

      {showApply && (
        <button
          onClick={handleApply}
          disabled={applying || applied}
          className={`min-h-[44px] w-full rounded-xl text-sm font-bold border transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-slate-900 active:scale-95 ${
            applied
              ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30 cursor-default'
              : applying
              ? 'bg-slate-800 text-slate-500 cursor-not-allowed border-slate-700'
              : cfg.btn
          }`}
        >
          {applied ? '✓ Applied successfully' : applying ? (
            <span className="flex items-center justify-center gap-2">
              <svg className="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
              </svg>
              Applying…
            </span>
          ) : '⚡ Apply Recommendation'}
        </button>
      )}

      {applyError && (
        <p className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2">{applyError}</p>
      )}
    </div>
  );
}
