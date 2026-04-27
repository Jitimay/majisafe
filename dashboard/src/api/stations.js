import client from './client.js';

export async function list() {
  const { data } = await client.get('/api/stations');
  return data;
}

export async function getStation(id) {
  const { data } = await client.get(`/api/stations/${id}`);
  return data;
}

export async function updateStation(id, payload) {
  const { data } = await client.patch(`/api/admin/stations/${id}`, payload);
  return data;
}

export async function cancelDispense(stationId) {
  const { data } = await client.post('/api/dispense/admin/cancel', { station_id: stationId });
  return data;
}
