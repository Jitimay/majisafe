import client from './client.js';

export async function sendCommand(stationId, { pump_number, action }) {
  const { data } = await client.post(`/api/pumps/${stationId}/command`, {
    pump_number,
    action,
  });
  return data;
}

export async function getStatus(stationId) {
  const { data } = await client.get(`/api/pumps/${stationId}/status`);
  return data;
}
