import client from './client.js';

export async function list() {
  const { data } = await client.get('/api/stations');
  return data;
}

export async function getStation(id) {
  const { data } = await client.get(`/api/stations/${id}`);
  return data;
}
