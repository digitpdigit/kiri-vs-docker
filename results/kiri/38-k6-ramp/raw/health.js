import http from 'k6/http';
import { check } from 'k6';
export default function () {
  const r = http.get(__ENV.BASE + '/health', { timeout: '5s' });
  check(r, { '200': (res) => res.status === 200 });
}
