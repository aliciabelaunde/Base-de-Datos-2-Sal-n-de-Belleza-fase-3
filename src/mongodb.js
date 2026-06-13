const { MongoClient } = require('mongodb');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017';
const DB_NAME   = 'coco_nosql';

let client;
let db;

async function connectMongo() {
    if (db) return db;
    client = new MongoClient(MONGO_URI);
    await client.connect();
    db = client.db(DB_NAME);
    console.log('✅ Conectado a MongoDB');
    return db;
}

function getMongo() {
    if (!db) throw new Error('MongoDB no conectado');
    return db;
}

module.exports = { connectMongo, getMongo };