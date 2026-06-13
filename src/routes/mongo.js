const express = require('express');
const router  = express.Router();
const jwt     = require('jsonwebtoken');
const { getMongo } = require('../mongodb');

function verificarToken(req, res, next) {
    const auth  = req.headers['authorization'];
    const token = auth && auth.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'Token requerido' });
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.usuario   = decoded;
        next();
    } catch (err) {
        return res.status(403).json({ error: 'Token inválido' });
    }
}

// ══ 1. HISTORIAL CLIENTES ════════════════════════════
router.get('/historial', verificarToken, async (req, res) => {
    try {
        const db   = getMongo();
        const data = await db.collection('historial_clientes').find({}).toArray();
        res.json(data);
    } catch(err) { res.status(500).json({ error: err.message }); }
});

router.get('/historial/:email', verificarToken, async (req, res) => {
    try {
        const db   = getMongo();
        const data = await db.collection('historial_clientes').findOne({ email: req.params.email });
        res.json(data);
    } catch(err) { res.status(500).json({ error: err.message }); }
});

router.post('/historial', verificarToken, async (req, res) => {
    try {
        const db     = getMongo();
        const result = await db.collection('historial_clientes').insertOne(req.body);
        res.json({ insertedId: result.insertedId });
    } catch(err) { res.status(500).json({ error: err.message }); }
});

// ══ 3. RESEÑAS ═══════════════════════════════════════
router.get('/resenas', verificarToken, async (req, res) => {
    try {
        const db   = getMongo();
        const data = await db.collection('resenas')
            .find({}).sort({ fecha: -1 }).toArray();
        res.json(data);
    } catch(err) { res.status(500).json({ error: err.message }); }
});

router.post('/resenas', verificarToken, async (req, res) => {
    try {
        const db     = getMongo();
        const result = await db.collection('resenas').insertOne({
            ...req.body,
            fecha: new Date()
        });
        res.json({ insertedId: result.insertedId });
    } catch(err) { res.status(500).json({ error: err.message }); }
});

// ══ 4. PREFERENCIAS CLIENTES ═════════════════════════
router.get('/preferencias/todos', verificarToken, async (req, res) => {
    try {
        const db   = getMongo();
        const data = await db.collection('preferencias_clientes').find({}).toArray();
        res.json(data);
    } catch(err) { res.status(500).json({ error: err.message }); }
});
router.get('/preferencias/:id', verificarToken, async (req, res) => {
    try {
        const db   = getMongo();
        const data = await db.collection('preferencias_clientes')
            .findOne({ personaID: req.params.id });
        res.json(data || {});
    } catch(err) { res.status(500).json({ error: err.message }); }
});

router.post('/preferencias', verificarToken, async (req, res) => {
    try {
        const db     = getMongo();
        const result = await db.collection('preferencias_clientes').updateOne(
            { personaID: req.body.personaID },
            { $set: req.body },
            { upsert: true }
        );
        res.json({ ok: true });
    } catch(err) { res.status(500).json({ error: err.message }); }
});

// ══ RESPONDER RESEÑA ═════════════════════════════════
router.put('/resenas/:id/responder', verificarToken, async (req, res) => {
    try {
        const { ObjectId } = require('mongodb');
        const db     = getMongo();
        const result = await db.collection('resenas').updateOne(
            { _id: new ObjectId(req.params.id) },
            { $set: {
                respuesta:      req.body.respuesta,
                fechaRespuesta: new Date(),
                respondidoPor:  req.usuario.rol
            }}
        );
        res.json({ ok: true });
    } catch(err) { res.status(500).json({ error: err.message }); }
});

// ── COMENTAR RESEÑA CBB ──────────────────────────────
router.post('/resenas/:id/comentar/cbb', verificarToken, async (req, res) => {
    try {
        const { ObjectId } = require('mongodb');
        const db = getMongo();
        await db.collection('resenas').updateOne(
            { _id: new ObjectId(req.params.id) },
            { $push: {
                comentarios: {
                    personaID:     req.usuario.personaID ? req.usuario.personaID.toString() : '',
                    nombreCliente: req.body.nombreCliente,
                    texto:         req.body.texto,
                    fecha:         new Date()
                }
            }}
        );
        res.json({ ok: true });
    } catch(err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;