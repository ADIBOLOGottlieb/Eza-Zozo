/**
 * Zones de livraison (mode de frais 'zone') : un prix par quartier, reconnaissance facultative
 * de la zone d'après la position du client (cercle centre + rayon, voir delivery-fee.js).
 *
 *  - GET  /api/delivery/zones              (public)  zones actives
 *  - GET  /api/admin/delivery-zones        (gérant)  toutes les zones
 *  - POST /api/admin/delivery-zones        (gérant)
 *  - PUT  /api/admin/delivery-zones/:id    (gérant)  champs absents conservés
 *  - DELETE /api/admin/delivery-zones/:id  (gérant)  zone déjà utilisée par une commande = désactivation
 */
const express = require('express');
const { db, currentRestaurantId } = require('./db');
const { requireManager } = require('./auth');
const { audit } = require('./monitor');
const { h, httpError } = require('./payments/util');
const { rid } = require('./restaurants');

const ORDER_BY = 'ORDER BY position, name COLLATE NOCASE, id';

/** JSON d'une zone (active en booléen). */
function presentZone(z) {
  if (!z) return null;
  return {
    id: z.id,
    name: z.name,
    fee: z.fee,
    active: !!z.active,
    position: z.position,
    center_lat: z.center_lat,
    center_lng: z.center_lng,
    radius_km: z.radius_km,
  };
}

/** Zone d'un restaurant (null si elle appartient à un autre restaurant). */
const getZone = (id, restaurantId) => db
  .prepare('SELECT * FROM delivery_zones WHERE id = ? AND restaurant_id = ?').get(Number(id), Number(restaurantId));

/** Zones actives d'un restaurant (pour le devis et la commande). */
function activeZones(restaurantId = currentRestaurantId()) {
  return db.prepare(`SELECT * FROM delivery_zones WHERE active = 1 AND restaurant_id = ? ${ORDER_BY}`).all(Number(restaurantId)).map(presentZone);
}

const toNum = (v) => (typeof v === 'number' ? v : typeof v === 'string' && v.trim() !== '' ? Number(v) : NaN);
const isNil = (v) => v === null || v === undefined || v === '';

/**
 * Valide une zone complète (après fusion avec l'existante pour PUT).
 * @returns valeurs prêtes pour la base
 */
function validateZone(body) {
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  if (!name || name.length > 60) throw httpError(400, 'Nom de la zone requis (60 caractères au plus)');
  const fee = toNum(body.fee);
  if (!Number.isInteger(fee) || fee < 0 || fee > 100000) throw httpError(400, 'Frais de la zone invalides (entier entre 0 et 100000)');
  if (![true, false, 0, 1, undefined].includes(body.active)) throw httpError(400, 'Valeur invalide pour active');
  const position = isNil(body.position) ? 0 : toNum(body.position);
  if (!Number.isInteger(position) || Math.abs(position) > 100000) throw httpError(400, 'Position invalide (entier)');
  // Cercle de reconnaissance : centre et rayon ensemble, ou aucun.
  const parts = [body.center_lat, body.center_lng, body.radius_km];
  const given = parts.filter((v) => !isNil(v)).length;
  let area = [null, null, null];
  if (given !== 0) {
    if (given !== 3) throw httpError(400, 'Zone : centre (latitude, longitude) et rayon doivent être renseignés ensemble');
    const [lat, lng, radius] = parts.map(toNum);
    if (!Number.isFinite(lat) || lat < -90 || lat > 90) throw httpError(400, 'Latitude du centre invalide (entre -90 et 90)');
    if (!Number.isFinite(lng) || lng < -180 || lng > 180) throw httpError(400, 'Longitude du centre invalide (entre -180 et 180)');
    if (!Number.isFinite(radius) || radius < 0.1 || radius > 50) throw httpError(400, 'Rayon invalide (entre 0,1 et 50 km)');
    area = [lat, lng, Math.round(radius * 100) / 100];
  }
  return { name, fee, active: body.active === false || body.active === 0 ? 0 : 1, position, area };
}

function createZonesRouter() {
  const router = express.Router();
  const body = (req) => (req.body && typeof req.body === 'object' && !Array.isArray(req.body) ? req.body : {});

  router.get('/api/delivery/zones', h((req, res) => {
    res.json(activeZones(rid(req)));
  }));

  router.get('/api/admin/delivery-zones', requireManager, h((req, res) => {
    res.json(db.prepare(`SELECT * FROM delivery_zones WHERE restaurant_id = ? ${ORDER_BY}`).all(rid(req)).map(presentZone));
  }));

  router.post('/api/admin/delivery-zones', requireManager, h((req, res) => {
    const z = validateZone(body(req));
    const info = db
      .prepare(`INSERT INTO delivery_zones (name, fee, active, position, center_lat, center_lng, radius_km, restaurant_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
      .run(z.name, z.fee, z.active, z.position, ...z.area, rid(req));
    const zone = presentZone(getZone(info.lastInsertRowid, rid(req)));
    audit('delivery_zone_created', { userId: req.user.id, details: zone, ip: req.ip });
    res.status(201).json(zone);
  }));

  router.put('/api/admin/delivery-zones/:id', requireManager, h((req, res) => {
    const before = getZone(req.params.id, rid(req));
    if (!before) throw httpError(404, 'Zone introuvable');
    const b = body(req);
    // Le cercle est remplacé seulement si l'un de ses champs est envoyé.
    const touchesArea = ['center_lat', 'center_lng', 'radius_km'].some((k) => b[k] !== undefined);
    const merged = {
      ...presentZone(before),
      ...(touchesArea ? { center_lat: null, center_lng: null, radius_km: null } : {}),
      ...b,
    };
    const z = validateZone(merged);
    db.prepare(`UPDATE delivery_zones SET name = ?, fee = ?, active = ?, position = ?, center_lat = ?, center_lng = ?, radius_km = ?
                WHERE id = ?`).run(z.name, z.fee, z.active, z.position, ...z.area, before.id);
    const zone = presentZone(getZone(before.id, rid(req)));
    audit('delivery_zone_updated', { userId: req.user.id, details: { before: presentZone(before), after: zone }, ip: req.ip });
    res.json(zone);
  }));

  router.delete('/api/admin/delivery-zones/:id', requireManager, h((req, res) => {
    const zone = getZone(req.params.id, rid(req));
    if (!zone) throw httpError(404, 'Zone introuvable');
    const used = db.prepare('SELECT 1 FROM orders WHERE delivery_zone_id = ? LIMIT 1').get(zone.id);
    if (used) {
      // Zone présente dans l'historique des commandes : désactivée, pas supprimée.
      db.prepare('UPDATE delivery_zones SET active = 0 WHERE id = ?').run(zone.id);
      audit('delivery_zone_deactivated', { userId: req.user.id, details: { id: zone.id, name: zone.name }, ip: req.ip });
      return res.json({ deleted: false, deactivated: true, zone: presentZone(getZone(zone.id, rid(req))) });
    }
    db.prepare('DELETE FROM delivery_zones WHERE id = ?').run(zone.id);
    audit('delivery_zone_deleted', { userId: req.user.id, details: { id: zone.id, name: zone.name }, ip: req.ip });
    res.json({ deleted: true, deactivated: false, zone: null });
  }));

  return router;
}

module.exports = { createZonesRouter, activeZones, presentZone };
