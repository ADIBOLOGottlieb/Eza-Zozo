const bcrypt = require('bcryptjs');
const { db, transaction } = require('./db');
const { normalizePhone } = require('./auth');

// Menu de démonstration Eza Zozo : du poisson, préparé de plusieurs façons.
const CATEGORIES = [
  { name: 'Poissons braisés', icon: 'fish' },
  { name: 'Poissons frits', icon: 'fish' },
  { name: 'Poissons en sauce', icon: 'soup' },
  { name: 'Accompagnements', icon: 'fries' },
  { name: 'Boissons', icon: 'drink' },
  { name: 'Packs', icon: 'pack' },
];

// Packs de démonstration : [nom, description, prix FCFA, populaire, image, [[nom du plat, quantité], ...]]
const PACKS = [
  ['Pack Solo', 'Tilapia braisé, attiéké et bissap pour une personne', 4500, 1, 'https://images.unsplash.com/photo-1510130387422-82bed34b37e9?w=800',
    [['Tilapia braisé', 1], ['Attiéké', 1], ['Bissap', 1]]],
  ['Pack Duo', 'Pour deux : tilapias frits, alloco et boissons', 8500, 0, 'https://images.unsplash.com/photo-1580476262798-bddd9f4b7369?w=800',
    [['Tilapia frit', 2], ['Alloco', 2], ['Bissap', 2]]],
  ['Pack Famille', 'Daurade et bar braisés avec accompagnements pour 4', 15500, 1, 'https://images.unsplash.com/photo-1611171711912-e3f6b536f532?w=800',
    [['Daurade braisée', 1], ['Bar braisé', 1], ['Attiéké', 4], ['Alloco', 2], ['Bissap', 4]]],
];

// [category index, name, description, price FCFA, popular, image (null = sans photo)]
const PRODUCTS = [
  [0, 'Tilapia braisé', 'Tilapia entier braisé au feu de bois, oignons et piment frais', 3500, 1, 'https://images.unsplash.com/photo-1510130387422-82bed34b37e9?w=800'],
  [0, 'Daurade braisée', 'Daurade entière marinée aux épices, braisée au charbon', 4500, 1, 'https://images.unsplash.com/photo-1611171711912-e3f6b536f532?w=800'],
  [0, 'Bar braisé', 'Bar (capitaine) braisé, sauce pimentée maison', 5500, 0, 'https://images.unsplash.com/photo-1611599537845-1c7aca0091c0?w=800'],
  [0, 'Brochettes de poisson (4 pcs)', 'Morceaux de poisson marinés et grillés en brochettes', 3000, 0, 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800'],
  [1, 'Tilapia frit', 'Tilapia entier frit, croustillant, servi avec sauce tomate pimentée', 3000, 1, 'https://images.unsplash.com/photo-1580476262798-bddd9f4b7369?w=800'],
  [1, 'Filet de poisson croustillant', 'Filets de poisson panés et frits, citron', 3000, 0, 'https://images.unsplash.com/photo-1580959375944-abd7e991f971?w=800'],
  [1, 'Chinchard frit', 'Chinchards frits, oignons et piment', 2000, 0, 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800'],
  [2, 'Poisson sauce tomate', 'Poisson mijoté dans une sauce tomate aux épices', 3500, 1, 'https://images.unsplash.com/photo-1574484284002-952d92456975?w=800'],
  [2, 'Poisson sauce feuilles', 'Poisson cuit dans une sauce aux feuilles vertes', 3500, 0, 'https://images.unsplash.com/photo-1485921325833-c519f76c4927?w=800'],
  [2, "Poisson à l'étouffée", "Poisson cuit à l'étouffée avec légumes frais", 4000, 0, 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800'],
  [3, 'Attiéké', "Portion d'attiéké frais", 700, 1, 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=800'],
  [3, 'Alloco', 'Bananes plantain frites', 1000, 1, 'https://images.unsplash.com/photo-1528751014936-863e6e7a319c?w=800'],
  [3, 'Akoumé', 'Pâte de maïs', 500, 0, null],
  [3, 'Frites maison', 'Frites croustillantes', 1000, 0, 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=800'],
  [3, 'Salade fraîche', 'Laitue, tomate, concombre, oignon', 1200, 0, 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800'],
  [4, 'Bissap', "Jus d'hibiscus maison (50 cl)", 700, 0, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=800'],
  [4, 'Gnamakoudji', 'Jus de gingembre maison (50 cl)', 700, 0, 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=800'],
  [4, 'Eau minérale', 'Bouteille 50 cl', 500, 0, null],
  [4, 'Coca-Cola', 'Canette 33 cl', 800, 0, 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=800'],
];

/**
 * Crée le compte admin (ADMIN_PHONE / ADMIN_PASSWORD). En production, sans ADMIN_PASSWORD, le mot de
 * passe par défaut est refusé : aucun admin n'est créé (le serveur démarre quand même).
 * @returns true si le compte a été créé.
 */
function createDefaultAdmin() {
  const password = process.env.ADMIN_PASSWORD || '';
  if (!password && process.env.NODE_ENV === 'production') {
    console.error(
      '❌ ADMIN_PASSWORD non défini en production : compte administrateur NON créé. ' +
        'Définissez ADMIN_PHONE et ADMIN_PASSWORD puis redémarrez le serveur.',
    );
    return false;
  }
  const phone = normalizePhone(process.env.ADMIN_PHONE || '71572566') || '71572566';
  if (db.prepare('SELECT id FROM users WHERE phone = ?').get(phone)) {
    console.error(`❌ ADMIN_PHONE ${phone} appartient déjà à un compte non administrateur : admin NON créé.`);
    return false;
  }
  // Premier compte du personnel : propriétaire (accès complet, ne peut être ni désactivé ni supprimé par un autre).
  db.prepare(`INSERT INTO users (name, phone, password_hash, role, admin_level) VALUES (?, ?, ?, 'admin', 'owner')`).run(
    'Administrateur', phone, bcrypt.hashSync(password || 'admin123', 10),
  );
  // Un mot de passe fourni par l'environnement n'est jamais écrit dans les journaux.
  console.log(
    password
      ? `👤 Compte admin créé : ${phone}`
      : `👤 Compte admin créé : ${phone} / admin123 (développement : changez le mot de passe !)`,
  );
  return true;
}

function seedIfEmpty() {
  const hasAdmin = db.prepare(`SELECT id FROM users WHERE role = 'admin' LIMIT 1`).get();
  if (!hasAdmin) createDefaultAdmin();

  const hasCategories = db.prepare('SELECT id FROM categories LIMIT 1').get();
  if (!hasCategories) {
    transaction(() => {
      const insertCat = db.prepare('INSERT INTO categories (name, icon, position) VALUES (?, ?, ?)');
      const ids = CATEGORIES.map((c, i) => insertCat.run(c.name, c.icon, i).lastInsertRowid);
      const insertProduct = db.prepare(
        'INSERT INTO products (category_id, name, description, price, popular, image_url) VALUES (?, ?, ?, ?, ?, ?)',
      );
      for (const [cat, name, desc, price, popular, img] of PRODUCTS) {
        insertProduct.run(ids[cat], name, desc, price, popular, img);
      }
      const idOf = (name) => db.prepare('SELECT id FROM products WHERE name = ?').get(name).id;
      const insertPack = db.prepare(
        `INSERT INTO products (category_id, name, description, price, popular, image_url, pack_items)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      );
      const packsCat = ids[CATEGORIES.findIndex((c) => c.name === 'Packs')];
      for (const [name, desc, price, popular, img, items] of PACKS) {
        const content = items.map(([product, quantity]) => ({ product_id: Number(idOf(product)), quantity }));
        insertPack.run(packsCat, name, desc, price, popular, img, JSON.stringify(content));
      }
    });
    console.log('🐟 Menu de démonstration ajouté');
  }
}

if (require.main === module) seedIfEmpty();

module.exports = { seedIfEmpty, createDefaultAdmin };
