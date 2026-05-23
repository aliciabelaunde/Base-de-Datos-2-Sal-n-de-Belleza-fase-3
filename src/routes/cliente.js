const express        = require('express');
const router         = express.Router();
const jwt            = require('jsonwebtoken');
const { sql, poolPromise } = require('../db');

function verificarToken(req, res, next) {
    const auth  = req.headers['authorization'];
    const token = auth && auth.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'Token requerido' });
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.usuario   = decoded;
        next();
    } catch (err) { return res.status(403).json({ error: 'Token inválido' }); }
}

// GET /api/cliente/perfil
router.get('/perfil', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('ClienteID', sql.Int, req.usuario.personaID)
            .execute('Ventas.SP_ObtenerPerfilCliente');
        if (!r.recordset.length) return res.status(404).json({ error: 'Perfil no encontrado' });
        res.json(r.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// PUT /api/cliente/perfil
router.put('/perfil', verificarToken, async (req, res) => {
    const { nombre, apellido, telefono, email, fechaNacimiento, alergias, contraindicaciones, notasTecnicas } = req.body;
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('ClienteID',          sql.Int,          req.usuario.personaID)
            .input('Nombre',             sql.VarChar(100), nombre)
            .input('Apellido',           sql.VarChar(100), apellido)
            .input('Telefono',           sql.VarChar(20),  telefono)
            .input('Email',              sql.VarChar(100), email)
            .input('FechaNacimiento',    sql.Date,         fechaNacimiento || null)
            .input('Alergias',           sql.VarChar(500), alergias || null)
            .input('Contraindicaciones', sql.VarChar(500), contraindicaciones || null)
            .input('NotasTecnicas',      sql.VarChar(500), notasTecnicas || null)
            .execute('Ventas.SP_ActualizarPerfilCliente');
        res.json(r.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/estadisticas
router.get('/estadisticas', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('ClienteID', sql.Int, req.usuario.personaID)
            .execute('Agenda.SP_EstadisticasCliente');
        res.json({
            proximaCita:        r.recordsets[0][0] || null,
            visitasAnio:        r.recordsets[1][0]?.VisitasAnio  || 0,
            totalGastado:       parseFloat(r.recordsets[2][0]?.TotalGastado || 0),
            promocionesActivas: r.recordsets[3][0]?.PromocionesActivas || 0
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/catalogo
router.get('/catalogo', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('CategoriaID', sql.Int, req.query.categoriaID ? parseInt(req.query.categoriaID) : null)
            .execute('Servicios.SP_ObtenerCatalogo');
        res.json(r.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/empleados-disponibles?servicioID=&fechaInicio=
router.get('/empleados-disponibles', verificarToken, async (req, res) => {
    const { servicioID, fechaInicio } = req.query;
    if (!servicioID || !fechaInicio)
        return res.status(400).json({ error: 'servicioID y fechaInicio son requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ServicioID',  sql.Int,          parseInt(servicioID))
            .input('FechaInicio', sql.NVarChar(30),  fechaInicio.replace('T',' ').substring(0,19))
            .execute('Agenda.SP_ObtenerEmpleadosDisponibles');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/cliente/citas
// POST /api/cliente/citas
router.post('/citas', verificarToken, async (req, res) => {
    const { fechaInicio, servicioIDs, empleadoIDs } = req.body;
    if (!fechaInicio || !servicioIDs) return res.status(400).json({ error: 'fechaInicio y servicioIDs son requeridos' });
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('ClienteID',   sql.Int,          req.usuario.personaID)
            .input('FechaInicio', sql.NVarChar(30),  fechaInicio.replace('T',' ').substring(0,19))
            .input('ServicioIDs', sql.VarChar(500),  servicioIDs)
            .input('EmpleadoIDs', sql.VarChar(500),  empleadoIDs || '0')
            .execute('Agenda.SP_ReservarCita');
        res.json(r.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/citas
router.get('/citas', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('ClienteID', sql.Int, req.usuario.personaID)
            .execute('Agenda.SP_ObtenerCitasCliente');
        res.json({ proximas: r.recordsets[0] || [], historial: r.recordsets[1] || [] });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// PUT /api/cliente/citas/:id/cancelar
router.put('/citas/:id/cancelar', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('CitaID',    sql.Int, parseInt(req.params.id))
            .input('ClienteID', sql.Int, req.usuario.personaID)
            .execute('Agenda.SP_CancelarCita');
        res.json(r.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// PUT /api/cliente/citas/:id/editar
router.put('/citas/:id/editar', verificarToken, async (req, res) => {
    const { nuevaFecha, nuevosEmpleados } = req.body;
    if (!nuevaFecha) return res.status(400).json({ error: 'nuevaFecha es requerida' });
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('CitaID',          sql.Int,          parseInt(req.params.id))
            .input('ClienteID',       sql.Int,          req.usuario.personaID)
            .input('NuevaFecha',      sql.DateTime,     new Date(nuevaFecha))
            .input('NuevosEmpleados', sql.VarChar(500), nuevosEmpleados || null)
            .execute('Agenda.SP_EditarCita');
        res.json(r.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/cliente/solicitud-especial
router.post('/solicitud-especial', verificarToken, async (req, res) => {
    const { fechaSolicitada, tipoSolicitud, servicioIDs, motivo } = req.body;
    if (!fechaSolicitada) return res.status(400).json({ error: 'fechaSolicitada es requerida' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ClienteID',       sql.Int,          req.usuario.personaID)
            .input('FechaSolicitada', sql.NVarChar(30), fechaSolicitada.replace('T',' ').substring(0,19))
            .input('TipoSolicitud',   sql.VarChar(30),  tipoSolicitud || null)
            .input('ServicioIDs',     sql.VarChar(500), servicioIDs   || null)
            .input('Motivo',          sql.VarChar(200), motivo        || null)
            .execute('Agenda.SP_CrearSolicitudEspecial');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/solicitudes
router.get('/solicitudes', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ClienteID', sql.Int, req.usuario.personaID)
            .execute('Agenda.SP_ObtenerSolicitudesCliente');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/compras
router.get('/compras', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('ClienteID',  sql.Int,  req.usuario.personaID)
            .input('FechaDesde', sql.Date, req.query.fechaDesde ? new Date(req.query.fechaDesde) : null)
            .input('FechaHasta', sql.Date, req.query.fechaHasta ? new Date(req.query.fechaHasta) : null)
            .execute('Ventas.SP_ObtenerComprasCliente');
        res.json(r.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/facturas
router.get('/facturas', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('ClienteID', sql.Int, req.usuario.personaID)
            .execute('Ventas.SP_ObtenerFacturasCliente');
        res.json(r.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/facturas/:id/detalle
router.get('/facturas/:id/detalle', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('FacturaID', sql.Int, parseInt(req.params.id))
            .execute('Facturacion.SP_DetalleFactura');
        res.json({
            cabecera:  r.recordsets[0][0] || null,
            servicios: r.recordsets[1]    || [],
            productos: r.recordsets[2]    || []
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/pagos
router.get('/pagos', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('ClienteID',  sql.Int,  req.usuario.personaID)
            .input('FechaDesde', sql.Date, req.query.fechaDesde ? new Date(req.query.fechaDesde) : null)
            .input('FechaHasta', sql.Date, req.query.fechaHasta ? new Date(req.query.fechaHasta) : null)
            .execute('Ventas.SP_ObtenerPagosCliente');
        res.json(r.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/promociones
router.get('/promociones', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .execute('Marketing.SP_ObtenerPromocionesActivas');

        const promos     = result.recordsets[0] || []; // generales
        const srvLinks   = result.recordsets[1] || []; // servicios de generales
        const bdayPromos = result.recordsets[2] || []; // cumpleaños

        // Mapa servicios por promoción
        const srvMap = {};
        const srvNombres = {};
        srvLinks.forEach(r => {
            if (!srvMap[r.PromocionID]) srvMap[r.PromocionID] = [];
            srvMap[r.PromocionID].push(r.ServicioID);
            if (!srvNombres[r.PromocionID]) srvNombres[r.PromocionID] = [];
            if (r.NombreServicio) srvNombres[r.PromocionID].push(r.NombreServicio);
        });

        // Promociones generales
        const data = promos.map(p => ({
            ...p,
            Descripcion:   p.Descripcion  || '',
            TipoPromocion: p.TipoPromocion || 'general',
            ServicioIDs:   srvMap[p.PromocionID] || [],
            NombresServicios: srvNombres[p.PromocionID] || []
        }));

        // Verificar si hoy es el cumpleaños del cliente
        if (bdayPromos.length > 0) {
            const bdayResult = await pool.request()
                .input('ClienteID', sql.Int, req.usuario.personaID)
                .query(`SELECT FechaNacimiento FROM Personas.Persona WHERE PersonaID = @ClienteID`);

            const fnac = bdayResult.recordset[0]?.FechaNacimiento;
            if (fnac) {
                const hoy        = new Date();
                // Extraer día y mes directamente del string para evitar problema de zona horaria
                const nacStr     = typeof fnac === 'string' ? fnac : fnac.toISOString();
                const nacMes     = parseInt(nacStr.substring(5, 7)) - 1; // 0-indexed
                const nacDia     = parseInt(nacStr.substring(8, 10));
                const esCumple   = hoy.getDate()  === nacDia &&
                                hoy.getMonth() === nacMes;

                if (esCumple) {
                    bdayPromos.forEach(p => {
                        data.push({
                            ...p,
                            Descripcion:   p.Descripcion || '¡Feliz cumpleaños! Este descuento es solo para ti hoy.',
                            TipoPromocion: 'cumpleaños',
                            ServicioIDs:   srvMap[p.PromocionID] || []
                        });
                    });
                }
            }
        }

        res.json(data);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/notificaciones
router.get('/notificaciones', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('PersonaID', sql.Int, req.usuario.personaID)
            .execute('Notificaciones.SP_ObtenerNotificaciones');
        res.json(r.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// PUT /api/cliente/notificaciones/:id/leer
router.put('/notificaciones/:id/leer', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('NotificacionID', sql.Int, parseInt(req.params.id))
            .input('PersonaID',      sql.Int, req.usuario.personaID)
            .execute('Notificaciones.SP_MarcarNotificacionLeida');
        res.json(r.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/cliente/slots-ocupados?fecha=&servicioIDs=
router.get('/slots-ocupados', verificarToken, async (req, res) => {
    const { fecha, servicioIDs } = req.query;
    if (!fecha) return res.status(400).json({ error: 'fecha es requerida' });
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('Fecha',       sql.Date,         new Date(fecha))
            .input('ServicioIDs', sql.VarChar(500),  servicioIDs || null)
            .execute('Agenda.SP_SlotsOcupados');
        res.json(r.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;