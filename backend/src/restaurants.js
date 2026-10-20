/**
 * Plusieurs restaurants pour un même propriétaire.
 *
 * Restaurant de chaque requête (middleware restaurantScope, monté après express.json) :
 *  - gérant et livreur : TOUJOURS leur restaurant (users.restaurant_id), quel que soit l'en-tête ;
 *  - propriétaire : en-tête `X-Restaurant-Id` (ou ?restaurant_id=) ; `all` = tous ses restaurants à la fois
 *    (lectures seulement : tableau de bord, commandes, rapports, encaissements) ;
 *  - client ou visiteur : restaurant choisi dans l'app (même en-tête), sinon le restaurant par défaut.
 * Sans en-tête, tout se passe comme avant le multi-restaurant (restaurant par défaut).
 *
 * Routes :
 *  - GET   /api/restaurants                 (public)        restaurants ouverts aux clients
 *  - GET   /api/owner/restaurants           (propriétaire)  tous les restaurants
 *  - POST  /api/owner/restaurants           (propriétaire)  { name, address?, phone?, copy_menu_from? }
 *  - PATCH /api/owner/restaurants/:id       (propriétaire)  { name?, active?, position? }
 *  - GET   /api/owner/overview              (propriétaire)  chiffres du jour de chaque restaurant + totaux
 */
const express = require('express');
const {
  db, transaction, getSettings, defaultRestaurantId, restaurantContext, currentRestaurantId, setRestaurantSetting,
  RESTAURANT_SETTING_KEYS,
} = require('./db');
const { authenticate, requireOwner } = require('./auth');
const hours = require('./hours');
const { audit } = require('./monitor');
const { h, httpError } = require('./payments/util');

const ALL = 'all';
const UNAVAILABLE = 'Ce restaurant n\'existe pas ou n\'accepte plus de commandes';

const getRestaurantRow = (id) => db.prepare('SELECT * FROM restaurants WHERE id = ?').get(Number(id));

const isOwnerUser = (user) => user?.role === 'admin' && user.admin_level === 'owner';

/** Restaurant demandé : null (absent), 'all', un entier > 0, ou NaN (illisible). */
function requestedRestaurant(req) {
  const header = req.get('x-restaurant-id');
  const raw = header !== undefined ? header : typeof req.query?.restaurant_id === 'string' ? req.query.restaurant_id : undefined;
  if (raw === undefined || String(raw).trim() === '') return null;
  const text = String(raw).trim().toLowerCase();
  if (text === ALL) return ALL;
  const n = Number(text);
  return Number.isInteger(n) && n > 0 ? n : NaN;
}

/** Remplit req.restaurantId / req.allRestaurants et ouvre le contexte du restaurant pour la suite de la requête. */
function restaurantScope(req, res, next) {
  let user = null;
  try {
    const r = authenticate(req);
    if (r.user) user = r.user;
  } catch {
    // jeton illisible : la route le refusera si elle exige une connexion
  }
  const requested = requestedRestaurant(req);
  const owner = isOwnerUser(user);
  let restaurantId = null;
  let all = false;
  let invalid = false;
  if (user && !owner && (user.role === 'driver' || user.role === 'admin')) {
    // Personnel d'un restaurant : jamais un autre restaurant.
    restaurantId = user.restaurant_id ?? defaultRestaurantId();
  } else if (requested === ALL && owner) {
    all = true;
  } else if (requested === null || requested === ALL) {
    restaurantId = defaultRestaurantId();
  } else {
    const row = Number.isNaN(requested) ? null : getRestaurantRow(requested);
    if (row && (row.active || owner)) {
      restaurantId = row.id;
    } else {
      // Restaurant inconnu ou fermé définitivement : les routes du catalogue et des commandes refusent (rid).
      invalid = true;
      restaurantId = defaultRestaurantId();
    }
  }
  req.restaurantId = all ? null : restaurantId;
  req.allRestaurants = all;
  req.restaurantInvalid = invalid;
  restaurantContext.run({ restaurantId: req.restaurantId }, next);
}

/** Restaurant concret de la requête (catalogue, commande, réglages, écriture). 400 en vue « tous ». */
function rid(req) {
  if (req.restaurantInvalid) throw httpError(404, UNAVAILABLE, 'restaurant_unavailable');
  if (req.allRestaurants) throw httpError(400, 'Choisissez un restaurant');
  return req.restaurantId ?? currentRestaurantId();
}

/** Filtre SQL du restaurant de la requête ; en vue « tous » (propriétaire) : aucun filtre. */
function scopeWhere(req, column = 'o.restaurant_id') {
  if (req.allRestaurants) return { sql: '1 = 1', params: [] };
  return { sql: `${column} = ?`, params: [rid(req)] };
}

/** Vrai si le compte peut agir sur ce restaurant (propriétaire : tous ; personnel : le sien). */
function canAccessRestaurant(user, restaurantId) {
  if (!user) return false;
  if (isOwnerUser(user)) return true;
  return Number(user.restaurant_id ?? defaultRestaurantId()) === Number(restaurantId);
}

/** 404 (comme une commande inexistante) si le restaurant n'est pas celui du compte. */
function assertRestaurantAccess(user, restaurantId, message = 'Introuvable') {
  if (!canAccessRestaurant(user, restaurantId)) throw httpError(404, message);
}

/** Restaurant au format API (+ adresse, téléphone, position et ouverture effective tirés de ses réglages). */
function presentRestaurant(r) {
  const s = getSettings(r.id);
  const state = hours.openState(s);
  return {
    id: r.id,
    name: r.name,
    active: !!r.active,
    position: r.position,
    address: s.restaurant_address,
    phone: s.restaurant_phone,
    lat: s.restaurant_lat,
    lng: s.restaurant_lng,
    is_open: !!r.active && state.is_open,
    next_opening_at: state.next_opening_at,
    created_at: r.created_at,
  };
}

const ORDER_BY = 'ORDER BY position, name COLLATE NOCASE, id';

function listRestaurants({ activeOnly = false } = {}) {
  return db.prepare(`SELECT * FROM restaurants ${activeOnly ? 'WHERE active = 1' : ''} ${ORDER_BY}`).all();
}

/** Nom affiché (80 caractères au plus). */
function checkName(raw) {
  const name = typeof raw === 'string' ? raw.trim() : '';
  if (!name) throw httpError(400, 'Nom du restaurant requis');
  return name.slice(0, 80);
}

/**
 * Recopie le menu (catégories, plats et packs) d'un restaurant dans un autre.
 * Les packs pointent vers les copies de leurs plats.
 */
function copyMenu(fromId, toId) {
  const catMap = new Map();
  for (const c of db.prepare('SELECT * FROM categories WHERE restaurant_id = ? ORDER BY position, id').all(fromId)) {
    const info = db.prepare('INSERT INTO categories (name, icon, position, restaurant_id) VALUES (?, ?, ?, ?)')
      .run(c.name, c.icon, c.position, toId);
    catMap.set(c.id, Number(info.lastInsertRowid));
  }
  const products = db.prepare('SELECT * FROM products WHERE restaurant_id = ? ORDER BY id').all(fromId);
  const prodMap = new Map();
  const insert = db.prepare(`INSERT INTO products (category_id, name, description, price, image_url, available, popular, pack_items, restaurant_id)
                             VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?)`);
  for (const p of products) {
    const info = insert.run(catMap.get(p.category_id) ?? null, p.name, p.description, p.price, p.image_url, p.available, p.popular, toId);
    prodMap.set(p.id, Number(info.lastInsertRowid));
  }
  // Contenu des packs, une fois tous les plats copiés.
  const setPack = db.prepare('UPDATE products SET pack_items = ? WHERE id = ?');
  for (const p of products) {
    if (!p.pack_items) continue;
    let items = [];
    try {
      items = JSON.parse(p.pack_items);
    } catch {
      items = [];
    }
    const mapped = (Array.isArray(items) ? items : [])
      .filter((i) => prodMap.has(i?.product_id))
      .map((i) => ({ product_id: prodMap.get(i.product_id), quantity: i.quantity }));
    if (mapped.length) setPack.run(JSON.stringify(mapped), prodMap.get(p.id));
  }
  return { categories: catMap.size, products: products.length };
}

/** Réglages recopiés depuis un autre restaurant (prix et règles), jamais l'adresse, le téléphone ni la position. */
const COPIED_SETTING_KEYS = RESTAURANT_SETTING_KEYS.filter(
  (k) => !['restaurant_phone', 'restaurant_address', 'restaurant_lat', 'restaurant_lng', 'is_open'].includes(k),
);

function createRouter() {
  const router = express.Router();
  const body = (req) => (req.body && typeof req.body === 'object' && !Array.isArray(req.body) ? req.body : {});

  router.get('/api/restaurants', h((_req, res) => {
    res.json(listRestaurants({ activeOnly: true }).map(presentRestaurant));
  }));

  router.get('/api/owner/restaurants', requireOwner, h((_req, res) => {
    const staff = db.prepare(
      `SELECT restaurant_id, SUM(CASE WHEN role = 'admin' THEN 1 ELSE 0 END) AS managers,
              SUM(CASE WHEN role = 'driver' THEN 1 ELSE 0 END) AS drivers
       FROM users WHERE deleted_at IS NULL AND COALESCE(active, 1) = 1 AND role IN ('admin', 'driver')
         AND COALESCE(admin_level, '') != 'owner' GROUP BY restaurant_id`,
    ).all();
    const fallback = defaultRestaurantId();
    const count = (id, field) => staff
      .filter((s) => Number(s.restaurant_id ?? fallback) === id)
      .reduce((n, s) => n + Number(s[field] || 0), 0);
    res.json(listRestaurants().map((r) => ({
      ...presentRestaurant(r),
      managers: count(r.id, 'managers'),
      drivers: count(r.id, 'drivers'),
    })));
  }));

  router.post('/api/owner/restaurants', requireOwner, h((req, res) => {
    const b = body(req);
    const name = checkName(b.name);
    let copyFrom = null;
    if (b.copy_menu_from !== undefined && b.copy_menu_from !== null && b.copy_menu_from !== '') {
      copyFrom = getRestaurantRow(b.copy_menu_from);
      if (!copyFrom) throw httpError(400, 'Restaurant à recopier introuvable');
    }
    const text = (v, label) => {
      if (v === undefined || v === null) return '';
      if (typeof v !== 'string') throw httpError(400, `${label} invalide`);
      return v.trim().slice(0, 200);
    };
    const address = text(b.address, 'Adresse');
    const phone = text(b.phone, 'Téléphone');
    const result = transaction(() => {
      const position = (db.prepare('SELECT MAX(position) AS m FROM restaurants').get()?.m ?? -1) + 1;
      const id = Number(db.prepare('INSERT INTO restaurants (name, position) VALUES (?, ?)').run(name, position).lastInsertRowid);
      let copied = null;
      if (copyFrom) {
        copied = copyMenu(copyFrom.id, id);
        const rows = db.prepare('SELECT key, value FROM restaurant_settings WHERE restaurant_id = ?').all(copyFrom.id);
        for (const r of rows) if (COPIED_SETTING_KEYS.includes(r.key)) setRestaurantSetting(id, r.key, r.value);
      } else {
        // Catégorie « Packs » prête, comme sur le premier restaurant.
        db.prepare(`INSERT INTO categories (name, icon, position, restaurant_id) VALUES ('Packs', 'pack', 0, ?)`).run(id);
      }
      if (address) setRestaurantSetting(id, 'restaurant_address', address);
      if (phone) setRestaurantSetting(id, 'restaurant_phone', phone);
      return { id, copied };
    });
    audit('restaurant_created', {
      userId: req.user.id,
      details: { restaurant_id: result.id, name, copy_menu_from: copyFrom?.id ?? null, ...(result.copied || {}) },
      ip: req.ip,
    });
    res.status(201).json(presentRestaurant(getRestaurantRow(result.id)));
  }));

  router.patch('/api/owner/restaurants/:id', requireOwner, h((req, res) => {
    const r = getRestaurantRow(req.params.id);
    if (!r) throw httpError(404, 'Restaurant introuvable');
    const b = body(req);
    const sets = [];
    const params = [];
    const changed = {};
    if (b.name !== undefined) {
      changed.name = checkName(b.name);
      sets.push('name = ?');
      params.push(changed.name);
    }
    if (b.position !== undefined) {
      const p = Number(b.position);
      if (!Number.isInteger(p) || Math.abs(p) > 100000) throw httpError(400, 'Position invalide (entier)');
      sets.push('position = ?');
      params.push(p);
      changed.position = p;
    }
    if (b.active !== undefined) {
      if (![true, false, 0, 1].includes(b.active)) throw httpError(400, 'Valeur invalide pour active');
      const active = b.active ? 1 : 0;
      if (!active && r.active) {
        const others = db.prepare('SELECT COUNT(*) AS n FROM restaurants WHERE active = 1 AND id != ?').get(r.id).n;
        if (!others) throw httpError(400, 'Au moins un restaurant doit rester actif');
      }
      sets.push('active = ?');
      params.push(active);
      changed.active = !!active;
    }
    if (sets.length) {
      db.prepare(`UPDATE restaurants SET ${sets.join(', ')} WHERE id = ?`).run(...params, r.id);
      audit('restaurant_updated', { userId: req.user.id, details: { restaurant_id: r.id, ...changed }, ip: req.ip });
    }
    res.json(presentRestaurant(getRestaurantRow(r.id)));
  }));

  router.get('/api/owner/overview', requireOwner, h((_req, res) => {
    res.json(ownerOverview());
  }));

  return router;
}

// Chiffre « encaissé ou à encaisser » : même règle que /api/admin/stats.
const COUNTED = `status != 'cancelled' AND (payment_method = 'cash' OR payment_status = 'paid')`;
const changePercent = (now, before) => (before ? Math.round(((now - before) / before) * 1000) / 10 : null);
const DAY_MS = 24 * 3600 * 1000;

/** Valeurs groupées par restaurant : Map restaurant_id → ligne. */
function byRestaurant(sql, ...params) {
  return new Map(db.prepare(sql).all(...params).map((r) => [Number(r.restaurant_id), r]));
}

/**
 * Vue d'ensemble du propriétaire : pour chaque restaurant, chiffres du jour (comparés au même jour de la
 * semaine dernière à la même heure), commandes en cours, paiements à vérifier, alertes et 7 derniers jours.
 */
function ownerOverview() {
  const today = byRestaurant(
    `SELECT restaurant_id, COUNT(*) AS orders, COALESCE(SUM(CASE WHEN ${COUNTED} THEN total END), 0) AS revenue,
            COUNT(CASE WHEN ${COUNTED} THEN 1 END) AS counted, COUNT(CASE WHEN status = 'cancelled' THEN 1 END) AS cancelled
     FROM orders WHERE date(created_at) = date('now') GROUP BY restaurant_id`,
  );
  const lastWeek = byRestaurant(
    `SELECT restaurant_id, COUNT(*) AS orders, COALESCE(SUM(CASE WHEN ${COUNTED} THEN total END), 0) AS revenue
     FROM orders WHERE date(created_at) = date('now', '-7 days') AND created_at <= datetime('now', '-7 days')
     GROUP BY restaurant_id`,
  );
  const live = byRestaurant(
    `SELECT restaurant_id, COUNT(*) AS active,
            COUNT(CASE WHEN status = 'pending' THEN 1 END) AS pending,
            COUNT(CASE WHEN status IN ('confirmed', 'preparing') THEN 1 END) AS kitchen,
            COUNT(CASE WHEN status = 'ready' THEN 1 END) AS ready,
            COUNT(CASE WHEN status = 'delivering' THEN 1 END) AS delivering
     FROM orders WHERE status NOT IN ('delivered', 'cancelled') GROUP BY restaurant_id`,
  );
  const fallback = defaultRestaurantId();
  const alerts = byRestaurant(
    `SELECT COALESCE(restaurant_id, ?) AS restaurant_id, COUNT(*) AS n,
            COUNT(CASE WHEN severity = 'critical' THEN 1 END) AS critical
     FROM alerts WHERE resolved = 0 GROUP BY COALESCE(restaurant_id, ?)`,
    fallback, fallback,
  );
  const review = byRestaurant(
    `SELECT o.restaurant_id, COUNT(DISTINCT p.id) AS n FROM payments p JOIN orders o ON o.id = p.order_id
     WHERE p.needs_review = 1
        OR (p.status = 'pending' AND p.created_at <= datetime('now', '-2 minutes')
            AND o.payment_status NOT IN ('paid', 'refunded') AND o.status != 'cancelled')
     GROUP BY o.restaurant_id`,
  );
  const dailyRows = db.prepare(
    `SELECT restaurant_id, date(created_at) AS day, COUNT(*) AS orders,
            COALESCE(SUM(CASE WHEN ${COUNTED} THEN total END), 0) AS revenue
     FROM orders WHERE date(created_at) >= date('now', '-6 days') GROUP BY restaurant_id, day`,
  ).all();
  const todayMs = Date.parse(`${new Date().toISOString().slice(0, 10)}T00:00:00Z`);
  const days = Array.from({ length: 7 }, (_, i) => new Date(todayMs - (6 - i) * DAY_MS).toISOString().slice(0, 10));
  const last7For = (id) => days.map((day) => {
    const r = dailyRows.find((x) => Number(x.restaurant_id) === id && x.day === day);
    return { day, orders: Number(r?.orders ?? 0), revenue: Number(r?.revenue ?? 0) };
  });
  const num = (map, id, field) => Number(map.get(id)?.[field] ?? 0);

  const restaurants = listRestaurants().map((r) => {
    const info = presentRestaurant(r);
    const s = getSettings(r.id);
    const revenue = num(today, r.id, 'revenue');
    const counted = num(today, r.id, 'counted');
    const lastWeekRevenue = num(lastWeek, r.id, 'revenue');
    return {
      id: r.id,
      name: r.name,
      active: !!r.active,
      address: info.address,
      phone: info.phone,
      is_open: info.is_open,
      manual_open: s.is_open,
      next_opening_at: info.next_opening_at,
      today: {
        orders: num(today, r.id, 'orders'),
        revenue,
        avg_basket: counted ? Math.round(revenue / counted) : 0,
        cancelled: num(today, r.id, 'cancelled'),
      },
      same_day_last_week: { orders: num(lastWeek, r.id, 'orders'), revenue: lastWeekRevenue },
      revenue_change_percent: changePercent(revenue, lastWeekRevenue),
      live: {
        active: num(live, r.id, 'active'),
        pending: num(live, r.id, 'pending'),
        kitchen: num(live, r.id, 'kitchen'),
        ready: num(live, r.id, 'ready'),
        delivering: num(live, r.id, 'delivering'),
      },
      alerts: num(alerts, r.id, 'n'),
      critical_alerts: num(alerts, r.id, 'critical'),
      payments_to_review: num(review, r.id, 'n'),
      last7_days: last7For(r.id),
    };
  });

  const sum = (pick) => restaurants.reduce((n, r) => n + pick(r), 0);
  const totalRevenue = sum((r) => r.today.revenue);
  const totalLastWeek = sum((r) => r.same_day_last_week.revenue);
  return {
    generated_at: new Date().toISOString(),
    restaurants,
    totals: {
      restaurants: restaurants.length,
      open: restaurants.filter((r) => r.is_open).length,
      orders: sum((r) => r.today.orders),
      revenue: totalRevenue,
      same_day_last_week_revenue: totalLastWeek,
      revenue_change_percent: changePercent(totalRevenue, totalLastWeek),
      active: sum((r) => r.live.active),
      pending: sum((r) => r.live.pending),
      alerts: sum((r) => r.alerts),
      payments_to_review: sum((r) => r.payments_to_review),
      last7_days: days.map((day, i) => ({
        day,
        orders: sum((r) => r.last7_days[i].orders),
        revenue: sum((r) => r.last7_days[i].revenue),
      })),
    },
  };
}

/** Nom d'un restaurant (null s'il n'existe pas). */
const restaurantName = (id) => getRestaurantRow(id)?.name ?? null;

module.exports = {
  createRouter, restaurantScope, rid, scopeWhere, canAccessRestaurant, assertRestaurantAccess, presentRestaurant,
  listRestaurants, getRestaurantRow, restaurantName, ownerOverview, copyMenu, isOwnerUser,
};
