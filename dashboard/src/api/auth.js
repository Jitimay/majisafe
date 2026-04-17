import client from './client.js';

export async function login(phone, password) {
  const { data } = await client.post('/api/auth/login', { phone, password });
  return data;
}
