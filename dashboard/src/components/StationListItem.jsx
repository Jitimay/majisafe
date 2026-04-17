import React from 'react';
import { useNavigate } from 'react-router-dom';

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

function TankBar({ level }) {
  const pct = Math.max(0, Math.min(100, level ?? 0));
  let color = 'bg-emerald-500';
  if (pct < 20) color = 'bg-red-500';
  else if (pct < 50) color = 'bg-amber-500';

  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 h-1.5 bg-slate-700 rounded-full overflow-hidden">
        <div
          className={`h-full rounded-full transition-all duration-700 ${color}`}
          style={{ width: `${pct}%` }}
        />
      </div>
      <span className="text-xs font-semibold text-slate-400 w-10 text-right">{Math.round(pct)}%</span>
    </div>
  );
}

export default function StationListItem({ station }) {
  const navigate = useNavigate();
  const isStale =
    station.last_seen &&
    station.status !== 'offline' &&
    Date.now() - new Date(station.last_seen).getTime() > 5 * 60 * 1000;

  return (
    <div
      onClick={() => navigate(`/stations/${station.id}`)}
      className="glass-card p-5 cursor-pointer hover:bg-slate-800/60 hover:border-emerald-500/30 transition-all duration-200 group"
    >
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-start gap-4 min-w-0">
          {/* Icon */}
          <div className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center shrink-0 group-hover:bg-emerald-500/20 transition-colors">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path d="M12 2C12 2 5 9.5 5 14a7 7 0 0014 0C19 9.5 12 2 12 2z" fill="#1D9E75"/>
            </svg>
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <h3 className="font-bold text-white text-sm">{station.name || station.id}</h3>
              {isStale && (
                <span className="px-2 py-0.5 rounded-full text-xs font-semibold bg-amber-500/20 text-amber-400 border border-amber-500/30">
                  Stale
                </span>
              )}
            </div>
            <p className="text-xs text-slate-500 mt-0.5">{station.location} · {station.id}</p>
            <div className="mt-2 w-48">
              <TankBar level={station.tank_level} />
            </div>
          </div>
        </div>

        <div className="flex flex-col items-end gap-2 shrink-0">
          <StatusBadge status={station.status} />
          <div className="flex items-center gap-1 text-xs text-slate-500">
            <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
            </svg>
            {station.last_seen
              ? new Date(station.last_seen).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
              : 'Never'}
          </div>
        </div>
      </div>

      {/* Arrow */}
      <div className="flex justify-end mt-3">
        <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2"
          className="text-slate-600 group-hover:text-emerald-400 group-hover:translate-x-1 transition-all duration-200">
          <path d="M9 18l6-6-6-6"/>
        </svg>
      </div>
    </div>
  );
}
