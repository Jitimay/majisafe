import React from 'react';
import StationListItem from './StationListItem.jsx';

export default function StationList({ stations = [] }) {
  if (stations.length === 0) {
    return (
      <div className="glass-card p-16 text-center">
        <div className="text-5xl mb-4">🏭</div>
        <p className="text-slate-400 text-sm font-medium">No stations found</p>
        <p className="text-slate-600 text-xs mt-1">Stations will appear here once they connect</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
      {stations.map((station) => (
        <StationListItem key={station.id} station={station} />
      ))}
    </div>
  );
}
