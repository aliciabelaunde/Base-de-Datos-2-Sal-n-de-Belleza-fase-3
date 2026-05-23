// src/routes/personal.js

const express              = require('express');
const router               = express.Router();
const jwt                  = require('jsonwebtoken');
const { sql, poolPromise } = require('../db');

// ══ MIDDLEWARE ════════════════════════════════════════
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

// ══ 1. AGENDA DEL DÍA ════════════════════════════════
// GET /api/personal/agenda
router.get('/agenda', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID', sql.Int, req.usuario.personaID)
            .execute('Agenda.SP_AgendaDelDia');
        res.json({
            estadisticas: result.recordsets[0][0] || {},
            timeline:     result.recordsets[1]    || [],
            semana:       result.recordsets[2][0] || {},
            semanaGrid:   result.recordsets[3]    || []
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 2. MI HORARIO ═════════════════════════════════════
// GET /api/personal/horario
// ══ 2. MI HORARIO ═════════════════════════════════════
// GET /api/personal/horario
router.get('/horario', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID', sql.Int, req.usuario.personaID)
            .execute('RRHH.SP_ObtenerHorarioEmpleado');

        const horarios = (result.recordsets[0] || []).map(h => {
            let entrada = '—';
            let salida  = '—';
            if (h.HoraEntrada instanceof Date) {
                entrada = h.HoraEntrada.toISOString().substring(11, 16);
            } else if (h.HoraEntrada) {
                entrada = String(h.HoraEntrada).substring(0, 5);
            }
            if (h.HoraSalida instanceof Date) {
                salida = h.HoraSalida.toISOString().substring(11, 16);
            } else if (h.HoraSalida) {
                salida = String(h.HoraSalida).substring(0, 5);
            }
            return {
                DiaSemana:   h.DiaSemana,
                HoraEntrada: entrada,
                HoraSalida:  salida,
                Activo:      h.Activo
            };
        });

        res.json({
            horarios:    horarios,
            excepciones: result.recordsets[1] || []
        });

    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 3. SOLICITAR EXCEPCIÓN ════════════════════════════
// POST /api/personal/horario/excepcion
router.post('/horario/excepcion', verificarToken, async (req, res) => {
    const { fecha, disponible, motivo } = req.body;
    if (!fecha) return res.status(400).json({ error: 'Fecha es requerida' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID',  sql.Int,        req.usuario.personaID)
            .input('Fecha', sql.Date, new Date(fecha + 'T12:00:00'))
            .input('Disponible',  sql.Bit,         disponible ? 1 : 0)
            .input('Motivo',      sql.VarChar(200), motivo || null)
            .execute('RRHH.SP_SolicitarExcepcion');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 4. MIS CLIENTES ═══════════════════════════════════
// GET /api/personal/clientes
router.get('/clientes', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID', sql.Int, req.usuario.personaID)
            .execute('Ventas.SP_ObtenerClientesEmpleado');
        res.json({
            clientes:     result.recordsets[0] || [],
            distribucion: result.recordsets[1] || [],
            retencion:    result.recordsets[2][0] || {}
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 5. FICHA DE CLIENTE ═══════════════════════════════
// GET /api/personal/clientes/:id/ficha
router.get('/clientes/:id/ficha', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ClienteID',  sql.Int, parseInt(req.params.id))
            .input('EmpleadoID', sql.Int, req.usuario.personaID)
            .execute('Ventas.SP_ObtenerFichaCliente');
        res.json({
            cliente:   result.recordsets[0][0] || null,
            historial: result.recordsets[1]    || [],
            citaActual: result.recordsets[2][0] || null
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 6. ACTUALIZAR NOTAS TÉCNICAS ══════════════════════
// PUT /api/personal/clientes/:id/notas
router.put('/clientes/:id/notas', verificarToken, async (req, res) => {
    const { notasTecnicas } = req.body;
    if (!notasTecnicas) return res.status(400).json({ error: 'Notas son requeridas' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ClienteID',     sql.Int,     parseInt(req.params.id))
            .input('NotasTecnicas', sql.VarChar,  notasTecnicas)
            .execute('Ventas.SP_ActualizarNotasTecnicas');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 7. COMPLETAR CITA ═════════════════════════════════
// PUT /api/personal/citas/:id/completar
router.put('/citas/:id/completar', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('CitaID',     sql.Int, parseInt(req.params.id))
            .input('EmpleadoID', sql.Int, req.usuario.personaID)
            .execute('Agenda.SP_CompletarCita');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 8. SUELDO Y COMISIONES ════════════════════════════
// GET /api/personal/sueldo
router.get('/sueldo', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID', sql.Int, req.usuario.personaID)
            .execute('RRHH.SP_ObtenerSueldoComisiones');
        res.json({
            sueldo:    result.recordsets[0][0] || {},
            mes:       result.recordsets[1][0] || {},
            semanas:   result.recordsets[2]    || [],
            historico: result.recordsets[3]    || []
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 9. MIS VENTAS ═════════════════════════════════════
// GET /api/personal/ventas
router.get('/ventas', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID', sql.Int, req.usuario.personaID)
            .execute('Ventas.SP_ObtenerVentasEmpleado');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 10. MI PERFIL ═════════════════════════════════════
// GET /api/personal/perfil
router.get('/perfil', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID', sql.Int, req.usuario.personaID)
            .execute('RRHH.SP_ObtenerPerfilEmpleado');
        res.json({
            perfil: result.recordsets[0][0] || null
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 11. ACTUALIZAR PERFIL ═════════════════════════════
// PUT /api/personal/perfil
router.put('/perfil', verificarToken, async (req, res) => {
    const { nombre, apellido, telefono, email } = req.body;
    if (!nombre || !apellido || !telefono || !email)
        return res.status(400).json({ error: 'Todos los campos son requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID', sql.Int,          req.usuario.personaID)
            .input('Nombre',     sql.VarChar(100),  nombre)
            .input('Apellido',   sql.VarChar(100),  apellido)
            .input('Telefono',   sql.VarChar(20),   telefono)
            .input('Email',      sql.VarChar(100),  email)
            .execute('RRHH.SP_ActualizarPerfilEmpleado');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 12. NOTIFICACIONES ════════════════════════════════
// GET /api/personal/notificaciones
router.get('/notificaciones', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('PersonaID', sql.Int, req.usuario.personaID)
            .execute('Notificaciones.SP_ObtenerNotificaciones');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 13. MARCAR NOTIFICACIÓN LEÍDA ═════════════════════
// PUT /api/personal/notificaciones/:id/leer
router.put('/notificaciones/:id/leer', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('NotificacionID', sql.Int, parseInt(req.params.id))
            .input('PersonaID',      sql.Int, req.usuario.personaID)
            .execute('Notificaciones.SP_MarcarNotificacionLeida');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;