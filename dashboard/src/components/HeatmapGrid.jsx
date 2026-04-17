import React from 'react';

const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const HOURS = Array.from({ length: 24 }, (_, i) => i);

function cellBg(value, max) {
  if (max === 0 || value === 0) return 'rgba(255,255,255,0.03)';
  const t = value / max;
  // Dark teal gradient
  const r = Math.round(2 + t * (16 - 2));
  const g = Math.round(6 + t * (185 - 6));
  const b = Math.round(23 + t * (129 - 23));
  return `rgba(${r},${g},${b},${0.2 + t * 0.8})`;
}

export default function HeatmapGrid({ matrix }) {
  if (!matrix || matrix.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-48 text-slate-600">
        <svg width="32" height="32" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5" className="mb-2">
          <rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/>
          <rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/>
        </svg>
        <p className="text-sm">No data yet</p>
      </div>
    );
  }

  const max = Math.max(...matrix.flat(), 0.001);

  return (
    <div className="overflow-x-auto">
      <div style={{ minWidth: 520 }}>
        {/* Hour labels */}
        <div className="flex ml-9 mb-1.5">
          {HOURS.map((h) => (
            <div key={h} className="flex-1 text-center" style={{ fontSize: 9, color: '#475569' }}>
              {h % 6 === 0 ? `${String(h).padStart(2, '0')}` : ''}
            </div>
          ))}
        </div>

        {/* Rows */}
        {DAYS.map((day, di) => (
          <div key={day} className="flex items-center mb-1">
            <div className="w-9 text-right pr-2 shrink-0" style={{ fontSize: 10, color: '#64748b' }}>{day}</div>
            {HOURS.map((h) => {
              const val = matrix[di]?.[h] ?? 0;
              return (
                <div
                  key={h}
                  className="flex-1 rounded-sm transition-all duration-300"
                  style={{ height: 16, backgroundColor: cellBg(val, max), margin: '0 1px' }}
                  title={`${day} ${String(h).padStart(2, '0')}:00 — ${val.toFixed(1)} L`}
                />
              );
            })}
          </div>
        ))}

        {/* Legend */}
        <div className="flex items-center gap-2 mt-3 ml-9">
          <span style={{ fontSize: 10, color: '#475569' }}>Low</span>
          <div className="h-2.5 rounded flex-1" style={{
            background: 'linear-gradient(to right, rgba(255,255,255,0.05), rgba(16,185,129,0.9))',
            maxWidth: 120,
          }} />
          <span style={{ fontSize: 10, color: '#475569' }}>High</span>
        </div>
      </div>
    </div>
  );
}
