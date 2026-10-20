const { db, getSettings, restaurantContext, listRestaurantIds } = require('./db');
const { log } = require('./logger');

/**
 * Restaurant concerné par une alerte ou une ligne d'audit : details.restaurant_id, sinon celui de la
 * commande citée (details.orderId), sinon celui de la requête ou de la tâche en cours ; null = commun.
 */
function restaurantOf(details) {
  const explicit = Number(details?.restaurant_id);
  if (Number.isInteger(explicit) && explicit > 0) return explicit;
  const orderId = Number(details?.orderId);
  if (Number.isInteger(orderId) && orderId > 0) {
    const row = db.prepare('SELECT restaurant_id FROM orders WHERE id = ?').get(orderId);
    if (row) return row.restaurant_id;
  }
  return restaurantContext.getStore()?.restaurantId ?? null;
}

/** Enregistre une action sensible dans le journal d'audit. */
function audit(action, { userId = null, details = null, ip = null } = {}) {
  db.prepare('INSERT INTO audit_logs (user_id, action, details, ip, restaurant_id) VALUES (?, ?, ?, ?, ?)').run(
    userId,
    action,
    details ? JSON.stringify(details) : null,
    ip,
    restaurantOf(details),
  );
}

/**
 * Crée une alerte, sauf si une alerte du même type (et même clé) existe déjà
 * sur la période [dedupeMinutes] : évite de noyer l'administrateur.
 */
function raiseAlert(type, severity, message, details = null, dedupeMinutes = 30) {
  const key = details?.key ?? null;
  const restaurantId = restaurantOf(details);
  const recent = db
    .prepare(
      `SELECT id, details FROM alerts WHERE type = ? AND created_at >= datetime('now', ?) AND restaurant_id IS ?`,
    )
    .all(type, `-${dedupeMinutes} minutes`, restaurantId)
    .some((a) => (key === null ? true : JSON.parse(a.details || '{}').key === key));
  if (recent) return null;
  const info = db
    .prepare('INSERT INTO alerts (type, severity, message, details, restaurant_id) VALUES (?, ?, ?, ?, ?)')
    .run(type, severity, message, details ? JSON.stringify(details) : null, restaurantId);
  log.warn('alerte', { type, severity, alert: message, details, restaurantId });
  return info.lastInsertRowid;
}

const count = (sql, ...params) => db.prepare(sql).get(...params).n;

/**
 * Nombre de commandes des 10 dernières minutes et moyenne par tranche de 10 min sur les 24 h précédentes.
 * [restaurantId] : un restaurant ; absent = tous.
 */
function orderRate(restaurantId = null) {
  const where = restaurantId ? 'AND restaurant_id = ?' : '';
  const params = restaurantId ? [Number(restaurantId)] : [];
  const last10 = count(`SELECT COUNT(*) AS n FROM orders WHERE created_at >= datetime('now', '-10 minutes') ${where}`, ...params);
  const prev24h = count(
    `SELECT COUNT(*) AS n FROM orders
     WHERE created_at >= datetime('now', '-1450 minutes') AND created_at < datetime('now', '-10 minutes') ${where}`,
    ...params,
  );
  return { last10, baselinePer10: prev24h / 144 };
}

/** Pic de commandes d'un restaurant (seuils de ses réglages). */
function checkSpike(restaurantId) {
  const s = getSettings(restaurantId);
  const { last10, baselinePer10 } = orderRate(restaurantId);
  if (last10 >= s.spike_min_orders && last10 >= s.spike_factor * Math.max(baselinePer10, 1)) {
    raiseAlert(
      'order_spike',
      last10 >= 2 * s.spike_min_orders ? 'critical' : 'warning',
      `Pic de commandes : ${last10} en 10 min (moyenne habituelle ${baselinePer10.toFixed(1)})`,
      { last10, baselinePer10, restaurant_id: restaurantId },
    );
  }
}

/** Contrôles exécutés chaque minute. */
function runChecks() {
  try {
    // 1. Pic de commandes, restaurant par restaurant (ex : attaque, bug, ou très forte affluence).
    for (const id of listRestaurantIds()) {
      restaurantContext.run({ restaurantId: id }, () => checkSpike(id));
    }

    // 2. Un même client qui enchaîne les commandes.
    const heavyUsers = db
      .prepare(
        `SELECT o.user_id, u.name, u.phone, COUNT(*) AS n FROM orders o JOIN users u ON u.id = o.user_id
         WHERE o.created_at >= datetime('now', '-10 minutes') GROUP BY o.user_id HAVING n >= 5`,
      )
      .all();
    for (const u of heavyUsers) {
      raiseAlert(
        'user_order_spike',
        'warning',
        `${u.name} (${u.phone}) a passé ${u.n} commandes en 10 min`,
        { key: `user-${u.user_id}`, userId: u.user_id, count: u.n },
        60,
      );
    }

    // 3. Paiements en échec en série.
    const failed = count(
      `SELECT COUNT(*) AS n FROM payments WHERE status = 'failed' AND updated_at >= datetime('now', '-15 minutes')`,
    );
    if (failed >= 5) {
      raiseAlert('payment_failures', 'warning', `${failed} paiements en échec en 15 min`, { failed });
    }

    // 4. Tentatives de connexion échouées (force brute).
    const loginFails = count(
      `SELECT COUNT(*) AS n FROM audit_logs WHERE action = 'login_failed' AND created_at >= datetime('now', '-15 minutes')`,
    );
    if (loginFails >= 20) {
      raiseAlert('bruteforce', 'critical', `${loginFails} connexions échouées en 15 min`, { loginFails });
    }

    // Nettoyage : on garde 90 jours d'audit.
    db.prepare(`DELETE FROM audit_logs WHERE created_at < datetime('now', '-90 days')`).run();
    // Alertes résolues de plus de 90 jours (les non résolues restent visibles).
    db.prepare(`DELETE FROM alerts WHERE resolved = 1 AND created_at < datetime('now', '-90 days')`).run();
  } catch (err) {
    log.error('monitoring', { error: err.message });
  }
}

/** Contrôle immédiat à la création d'une commande (montant anormal). */
function checkOrder(order, user) {
  const s = getSettings(order.restaurant_id ?? undefined);
  if (order.total >= s.high_amount_alert) {
    raiseAlert(
      'high_amount',
      'warning',
      `Commande n°${order.id} d'un montant élevé : ${order.total} FCFA (${user?.name ?? 'client'})`,
      { key: `order-${order.id}`, orderId: order.id, total: order.total },
      0,
    );
  }
}

function startMonitoring() {
  runChecks();
  return setInterval(runChecks, 60 * 1000).unref();
}

module.exports = { audit, raiseAlert, runChecks, checkOrder, startMonitoring, orderRate };
