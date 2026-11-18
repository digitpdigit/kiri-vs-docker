import http from 'k6/http';
import { check } from 'k6';

export let options = {
  vus: 10,
  duration: '30s',
};

const BASE = 'http://127.0.0.1:8080';

export default function () {
  let endpoints = ['/health', '/db', '/cache'];
  let url = BASE + endpoints[Math.floor(Math.random() * endpoints.length)];
  let r = http.get(url, { timeout: '5s' });
  check(r, { 'status < 503': (res) => res.status < 503 });
}
