import React, { useEffect, useRef, useState } from 'react';

export default function TankGauge({ level = 0, isOffline = false, animationDuration = 700, size = 160 }) {
  const [displayLevel, setDisplayLevel] = useState(level);
  const animRef = useRef(null);
  const startRef = useRef(level);
  const startTimeRef = useRef(null);

  useEffect(() => {
    const from = displayLevel;
    const to = level;
    if (Math.abs(from - to) < 0.1) return;
    startRef.current = from;
    startTimeRef.current = null;
    const animate = (ts) => {
      if (!startTimeRef.current) startTimeRef.current = ts;
      const p = Math.min((ts - startTimeRef.current) / animationDuration, 1);
      const e = 1 - Math.pow(1 - p, 3);
      setDisplayLevel(from + (to - from) * e);
      if (p < 1) animRef.current = requestAnimationFrame(animate);
    };
    animRef.current = requestAnimationFrame(animate);
    return () => cancelAnimationFrame(animRef.current);
  }, [level]); // eslint-disable-line

  const cx = size / 2, cy = size / 2;
  const r = size * 0.38;
  const sw = size * 0.075;
  const clamp = Math.max(0, Math.min(100, displayLevel));

  const startAngle = 135, totalSweep = 270;
  const fillSweep = (clamp / 100) * totalSweep;

  function polar(angle) {
    const rad = ((angle - 90) * Math.PI) / 180;
    return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
  }
  function arc(start, sweep) {
    if (sweep <= 0) return '';
    const s = polar(start), e = polar(start + sweep);
    return `M ${s.x} ${s.y} A ${r} ${r} 0 ${sweep > 180 ? 1 : 0} 1 ${e.x} ${e.y}`;
  }

  let color = '#10b981'; // emerald
  let glowColor = 'rgba(16,185,129,0.4)';
  if (clamp < 20) { color = '#ef4444'; glowColor = 'rgba(239,68,68,0.4)'; }
  else if (clamp < 50) { color = '#f59e0b'; glowColor = 'rgba(245,158,11,0.4)'; }

  const gradId = `gauge-grad-${Math.round(clamp)}`;

  return (
    <div className="relative inline-flex items-center justify-center">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: isOffline ? 'none' : `drop-shadow(0 0 12px ${glowColor})` }}>
        <defs>
          <linearGradient id={gradId} x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor={color} stopOpacity="0.6" />
            <stop offset="100%" stopColor={color} stopOpacity="1" />
          </linearGradient>
        </defs>

        {/* Track */}
        <path d={arc(startAngle, totalSweep)} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth={sw} strokeLinecap="round" />

        {/* Fill */}
        {fillSweep > 0 && !isOffline && (
          <path d={arc(startAngle, fillSweep)} fill="none" stroke={`url(#${gradId})`} strokeWidth={sw} strokeLinecap="round" />
        )}

        {/* Centre */}
        {isOffline ? (
          <>
            <circle cx={cx} cy={cy} r={r * 0.65} fill="rgba(100,116,139,0.15)" />
            <text x={cx} y={cy + 5} textAnchor="middle" fontSize={size * 0.09} fontWeight="700" fill="#64748b">Offline</text>
          </>
        ) : (
          <>
            <text x={cx} y={cy - size * 0.04} textAnchor="middle" fontSize={size * 0.22} fontWeight="900" fill="white">
              {Math.round(clamp)}
            </text>
            <text x={cx} y={cy + size * 0.12} textAnchor="middle" fontSize={size * 0.09} fontWeight="600" fill={color}>
              %
            </text>
            <text x={cx} y={cy + size * 0.24} textAnchor="middle" fontSize={size * 0.075} fill="rgba(148,163,184,0.7)">
              TANK
            </text>
          </>
        )}
      </svg>
    </div>
  );
}
