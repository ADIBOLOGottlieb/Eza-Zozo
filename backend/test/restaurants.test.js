// Plusieurs restaurants (node --test) : catalogue et commandes par restaurant, gérants et livreurs cloisonnés,
// vue d'ensemble du propriétaire. Serveur de test sur le port 4630 (base temporaire).
const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');
const bcrypt = require('bcryptjs');

const BACKEND = path.join(__dirname, '..');
const PORT = 4630;
const BASE = `http://localhost:${PORT}`;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function startServer(dir) {
  const env = {
    ...process.env, PORT: String(PORT), DB_PATH: path.join(dir, 'restaurants.db'), LOG_DIR: path.join(dir, 'logs'), LOG_CONSOLE: '0',
    JWT_SECRET: 'test-secret-restaurants', ADMIN_PHONE: '0700000000', ADMIN_PASSWORD: 'admin123', NODE_ENV: 'test',
    PAYMENT_PROVIDER: '', PAYGATE_AUTH_TOKEN: '', KADEV_PUBLIC_KEY: '', KADEV_SECRET_KEY: '', ALLOW_SIMULATION: '',
    PROVIDER_FEE_PERCENT: '', PROVIDER_FEE_PERCENT_FLOOZ: '', PROVIDER_FEE_PERCENT_MIXX: '', SMS_PROVIDER: '',
    FIREBASE_SERVICE_ACCOUNT: '', BACKUP_GITHUB_REPO: '', BACKUP_GITHUB_TOKEN: '', MERCHANT_DISPLAY_NAME: '',
    NOMINATIM_URL: 'http://127.0.0.1:9', OSRM_URL: 'http://127.0.0.1:9',
    PAYMENT_TASK_INTERVAL_MS: '600000', RECONCILE_DELAY_MS: '3600000', DELIVERY_TASK_INTERVAL_MS: '600000',
  };
  const child = spawn(process.execPath, ['src/server.js'], { cwd: BACKEND, env, stdio: ['ignore', 'pipe', 'pipe'] });
  let out = '';
  child.stdout.on('data', (d) => (out += d));
  child.stderr.on('data', (d) => (out += d));
  return { child, out: () => out };
}
const stop = (srv) => new Promise((r) => {
  if (srv.child.exitCode !== null) return r();
  srv.child.once('exit', r);
  srv.child.kill();
});
async function waitHealth(srv) {
  for (let i = 0; i < 80; i++) {
    try {
      if ((await fetch(`${BASE}/api/health`)).ok) {
        await sleep(300);
        if (srv.child.exitCode !== null) throw new Error(`port ${PORT} occupé\n${srv.out()}`);
        return;
      }
    } catch (err) {
      if (/occupé/.test(err.message)) throw err;
    }
    if (srv.child.exitCode !== null) break;
    await sleep(150);
  }
  throw new Error(`serveur injoignable\n${srv.out()}`);
}

/** Client HTTP ; [restaurant] : en-tête X-Restaurant-Id envoyé à chaque appel (modifiable). */
function client(token = null, restaurant = null) {
  const c = {
    restaurant,
    async call(method, p, body, extraHeaders = {}) {
      const res = await fetch(BASE + p, {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...(c.restaurant !== null ? { 'X-Restaurant-Id': String(c.restaurant) } : {}),
          ...extraHeaders,
        },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      const text = await res.text();
      let data = text;
      try { data = JSON.parse(text); } catch {}
      return { status: res.status, data };
    },
    setToken: (t) => (token = t),
  };
  return c;
}
async function login(phone, password, restaurant = null) {
  const c = client(null, restaurant);
  const r = await c.call('POST', '/api/auth/login', { phone, password });
  assert.equal(r.status, 200, JSON.stringify(r.data));
  c.setToken(r.data.token);
  c.user = r.data.user;
  return c;
}

test('plusieurs restaurants : catalogue, commandes, personnel, vue d\'ensemble', async (t) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ezazozo-restaurants-'));
  const srv = startServer(dir);
  t.after(() => stop(srv));
  await waitHealth(srv);
  const sql = new DatabaseSync(path.join(dir, 'restaurants.db'));
  sql.exec('PRAGMA busy_timeout = 5000');
  t.after(() => sql.close());

  const owner = await login('0700000000', 'admin123');
  assert.equal(owner.user.admin_level, 'owner');
  assert.equal(owner.user.restaurant_id, null, 'le propriétaire suit tous ses restaurants');
  const hash = bcrypt.hashSync('secret123', 4);
  let seq = 0;
  async function customer(restaurant) {
    const local = String(93100000 + ++seq);
    sql.prepare('INSERT INTO users (name, phone, password_hash) VALUES (?, ?, ?)').run(`Client ${seq}`, `+228${local}`, hash);
    return login(local, 'secret123', restaurant);
  }
  const order = (c, productId, extra = {}) => c.call('POST', '/api/orders', {
    items: [{ product_id: productId, quantity: 2 }], phone: '90111111', mode: 'pickup', payment_method: 'cash', ...extra,
  });

  // ---------- Restaurant par défaut et création ----------
  let r = await client().call('GET', '/api/restaurants');
  assert.equal(r.status, 200);
  assert.equal(r.data.length, 1, 'la base existante devient le restaurant n°1');
  assert.equal(r.data[0].id, 1);
  const menu1 = (await client().call('GET', '/api/products')).data;
  assert.ok(menu1.length > 5, 'menu de démonstration au restaurant n°1');

  r = await owner.call('POST', '/api/owner/restaurants', { name: 'Eza Zozo Bè', address: 'Bè, Lomé', copy_menu_from: 1 });
  assert.equal(r.status, 201, JSON.stringify(r.data));
  const B = r.data.id;
  assert.equal(r.data.address, 'Bè, Lomé');
  r = await owner.call('POST', '/api/owner/restaurants', { name: 'Eza Zozo Kara' });
  assert.equal(r.status, 201);
  const C = r.data.id;
  assert.equal((await client().call('POST', '/api/owner/restaurants', { name: 'X' })).status, 401);

  const menuB = (await client(null, B).call('GET', '/api/products')).data;
  assert.equal(menuB.length, menu1.length, 'menu recopié');
  assert.ok(menuB.every((p) => !menu1.some((q) => q.id === p.id)), 'plats copiés = nouveaux identifiants');
  const packB = menuB.find((p) => p.is_pack);
  assert.ok(packB && packB.pack_items.every((i) => menuB.some((p) => p.id === i.product_id)), 'pack recopié avec ses propres plats');
  assert.deepEqual((await client(null, C).call('GET', '/api/products')).data, [], 'nouveau restaurant sans menu');
  const catsC = (await client(null, C).call('GET', '/api/categories')).data;
  assert.deepEqual(catsC.map((c) => c.name), ['Packs']);

  // Restaurant inconnu : refusé (l'app propose alors de choisir un autre restaurant).
  r = await client(null, 999).call('GET', '/api/products');
  assert.equal(r.status, 404);
  assert.equal(r.data.code, 'restaurant_unavailable');

  // ---------- Commandes : chacune dans son restaurant ----------
  const clientB = await customer(B);
  const dishB = menuB.find((p) => !p.is_pack && p.price >= 2000);
  const dish1 = menu1.find((p) => p.name === dishB.name);
  r = await order(clientB, dish1.id);
  assert.equal(r.status, 400, 'un plat d\'un autre restaurant est refusé');
  r = await order(clientB, dishB.id);
  assert.equal(r.status, 201, JSON.stringify(r.data));
  const orderB = r.data;
  assert.equal(orderB.restaurant_id, B);
  assert.equal(orderB.restaurant_name, 'Eza Zozo Bè');
  const client1 = await customer(null);
  r = await order(client1, dish1.id, { mode: 'delivery', address: 'Tokoin', location: { lat: 6.13, lng: 1.22 } });
  assert.equal(r.status, 201, JSON.stringify(r.data));
  const order1 = r.data;
  assert.equal(order1.restaurant_id, 1);
  // Le client voit toutes ses commandes, quel que soit le restaurant choisi.
  clientB.restaurant = 1;
  assert.ok((await clientB.call('GET', '/api/orders')).data.some((o) => o.id === orderB.id));

  // ---------- Réglages propres à chaque restaurant ----------
  r = await owner.call('PUT', '/api/admin/settings', { is_open: false, min_order: 0 }, { 'X-Restaurant-Id': String(B) });
  assert.equal(r.status, 200, JSON.stringify(r.data));
  assert.equal(r.data.restaurant_id, B);
  assert.equal((await client(null, B).call('GET', '/api/settings')).data.is_open, false);
  assert.equal((await client(null, 1).call('GET', '/api/settings')).data.is_open, true, 'les autres restaurants restent ouverts');
  clientB.restaurant = B;
  r = await order(clientB, dishB.id);
  assert.equal(r.status, 400, 'restaurant fermé');
  await owner.call('PUT', '/api/admin/settings', { is_open: true }, { 'X-Restaurant-Id': String(B) });

  // ---------- Gérant : uniquement son restaurant ----------
  r = await owner.call('POST', '/api/admin/staff', { name: 'Gérant Bè', phone: '91 55 55 55', password: 'gerantb', restaurant_id: B });
  assert.equal(r.status, 201, JSON.stringify(r.data));
  assert.equal(r.data.restaurant_id, B);
  const managerB = await login('91555555', 'gerantb', 1); // même en demandant le restaurant 1
  assert.equal(managerB.user.restaurant_id, B);
  assert.equal(managerB.user.restaurant_name, 'Eza Zozo Bè');
  const listB = (await managerB.call('GET', '/api/admin/orders')).data;
  assert.deepEqual(listB.map((o) => o.id), [orderB.id], 'le gérant ne voit que son restaurant');
  assert.equal((await managerB.call('GET', `/api/orders/${order1.id}`)).status, 404);
  assert.equal((await managerB.call('PATCH', `/api/admin/orders/${order1.id}/status`, { status: 'confirmed' })).status, 404);
  assert.equal((await managerB.call('PATCH', `/api/admin/orders/${orderB.id}/status`, { status: 'confirmed' })).status, 200);
  assert.equal((await managerB.call('GET', '/api/admin/stats')).data.today.orders, 1);
  const staffSeenByB = (await managerB.call('GET', '/api/admin/staff')).data;
  assert.ok(staffSeenByB.every((s) => s.restaurant_id === null || s.restaurant_id === B));
  // Son menu : un plat du restaurant n°1 est introuvable pour lui.
  assert.equal((await managerB.call('PATCH', `/api/admin/products/${dish1.id}/availability`, { available: false })).status, 404);
  assert.equal((await client(null, 1).call('GET', '/api/products')).data.some((p) => p.id === dish1.id), true);

  // ---------- Livreur : livraisons de son restaurant ----------
  r = await managerB.call('POST', '/api/admin/drivers', { name: 'Livreur Bè', phone: '92 66 66 66', password: 'livreur1' });
  assert.equal(r.status, 201, JSON.stringify(r.data));
  assert.equal(r.data.restaurant_id, B);
  await owner.call('PATCH', `/api/admin/orders/${order1.id}/status`, { status: 'ready' });
  const driverB = await login('92666666', 'livreur1');
  const available = (await driverB.call('GET', '/api/driver/orders?scope=available')).data;
  assert.ok(!available.some((o) => o.id === order1.id), 'commande prête d\'un autre restaurant invisible');
  assert.equal((await driverB.call('POST', `/api/driver/orders/${order1.id}/take`)).status, 404);
  r = await owner.call('PATCH', `/api/admin/orders/${order1.id}/assign`, { driver_id: driverB.user.id });
  assert.equal(r.status, 400, 'livreur d\'un autre restaurant');

  // ---------- Propriétaire : tous les restaurants ----------
  const ownerAll = await login('0700000000', 'admin123', 'all');
  const ids = (await ownerAll.call('GET', '/api/admin/orders')).data.map((o) => o.id).sort((a, b) => a - b);
  assert.deepEqual(ids, [order1.id, orderB.id].sort((a, b) => a - b));
  assert.equal((await ownerAll.call('GET', '/api/admin/stats')).data.today.orders, 2);
  assert.equal((await ownerAll.call('POST', '/api/admin/products', { name: 'X', price: 1000 })).status, 400, 'écriture : choisir un restaurant');
  const report = (await ownerAll.call('GET', '/api/admin/reports')).data;
  assert.equal(report.by_restaurant.length, 2);
  assert.equal(report.totals.orders, report.by_restaurant.reduce((n, x) => n + x.orders, 0));

  const overview = (await owner.call('GET', '/api/owner/overview')).data;
  assert.equal(overview.restaurants.length, 3);
  assert.equal(overview.totals.orders, 2);
  assert.equal(overview.totals.revenue, orderB.total + order1.total, 'commandes en espèces comptées');
  assert.equal(overview.restaurants.find((x) => x.id === B).today.orders, 1);
  assert.equal(overview.restaurants.find((x) => x.id === C).today.orders, 0);
  assert.equal(overview.totals.last7_days.length, 7);
  assert.equal((await managerB.call('GET', '/api/owner/overview')).status, 403);

  // ---------- Désactivation ----------
  r = await owner.call('PATCH', `/api/owner/restaurants/${C}`, { active: false });
  assert.equal(r.status, 200);
  assert.ok(!(await client().call('GET', '/api/restaurants')).data.some((x) => x.id === C));
  assert.equal((await client(null, C).call('GET', '/api/products')).status, 404);
  await owner.call('PATCH', `/api/owner/restaurants/${B}`, { active: false });
  r = await owner.call('PATCH', '/api/owner/restaurants/1', { active: false });
  assert.equal(r.status, 400, 'au moins un restaurant actif');

  // Journal d'audit rattaché au restaurant de la commande.
  const auditRow = sql.prepare(`SELECT restaurant_id FROM audit_logs WHERE action = 'order_created' AND details LIKE ?`).get(`%"orderId":${orderB.id}%`);
  assert.equal(auditRow.restaurant_id, B);
});
