import { auth } from '../config/firebase.js';

const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000';

async function getToken() {
  const user = auth.currentUser;
  if (!user) throw new Error('Not authenticated');
  return await user.getIdToken();
}

async function headers() {
  const token = await getToken();
  return {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
  };
}

async function handleResponse(response) {
  if (response.ok) {
    const text = await response.text();
    return text ? JSON.parse(text) : null;
  }
  if (response.status === 401) {
    window.location.href = '/login';
    throw new Error('Session expired');
  }
  const err = await response.text();
  throw new Error(err || `Request failed: ${response.status}`);
}

const api = {
  async get(endpoint) {
    const res = await fetch(`${BASE_URL}${endpoint}`, {
      headers: await headers(),
    });
    return handleResponse(res);
  },

  async post(endpoint, body) {
    const res = await fetch(`${BASE_URL}${endpoint}`, {
      method: 'POST',
      headers: await headers(),
      body: JSON.stringify(body),
    });
    return handleResponse(res);
  },

  async put(endpoint, body) {
    const res = await fetch(`${BASE_URL}${endpoint}`, {
      method: 'PUT',
      headers: await headers(),
      body: JSON.stringify(body),
    });
    return handleResponse(res);
  },

  async delete(endpoint) {
    const res = await fetch(`${BASE_URL}${endpoint}`, {
      method: 'DELETE',
      headers: await headers(),
    });
    return handleResponse(res);
  },

  async upload(file) {
    const token = await getToken();
    const formData = new FormData();
    formData.append('file', file);
    const res = await fetch(`${BASE_URL}/uploads`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${token}` },
      body: formData,
    });
    return handleResponse(res);
  },
};

export default api;
