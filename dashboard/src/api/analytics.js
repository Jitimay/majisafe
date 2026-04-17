import client from './client.js';

export async function getRecommendation(stationId) {
  const { data } = await client.get(`/api/analytics/${stationId}/recommendation`);
  return data;
}

export async function getTankHistory(stationId, { from, to } = {}) {
  const params = {};
  if (from) params.from = from;
  if (to)   params.to   = to;
  const { data } = await client.get(`/api/analytics/${stationId}/tank-history`, { params });
  return data;
}

export async function getDailyUsage(stationId, days = 7) {
  const { data } = await client.get(`/api/analytics/${stationId}/daily-usage`, {
    params: { days },
  });
  return data;
}

export async function getHourlyHeatmap(stationId) {
  const { data } = await client.get(`/api/analytics/${stationId}/hourly-heatmap`);
  return data;
}

export async function getDepletionRate(stationId) {
  const { data } = await client.get(`/api/analytics/${stationId}/depletion-rate`);
  return data;
}

export async function getTimeToEmpty(stationId) {
  const { data } = await client.get(`/api/analytics/${stationId}/time-to-empty`);
  return data;
}
