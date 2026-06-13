const express              = require('express');
const router               = express.Router();
const jwt                  = require('jsonwebtoken');
const bcrypt               = require('bcrypt');
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

// ══ 1. PANEL GENERAL ══════════════════════════════════
// GET /api/atencion/panel
router.get('/panel', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .execute('Agenda.SP_PanelRecepcion');
        res.json({
            estadisticas:  result.recordsets[0][0] || {},
            proximaCita:   result.recordsets[1][0] || null,
            ventas:        result.recordsets[2][0] || {},
            clientes:      result.recordsets[3][0] || {},
            citasHoy:      result.recordsets[4]    || [],
            disponibilidad: result.recordsets[5]   || []
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 2. GESTIÓN DE CITAS ═══════════════════════════════
// GET /api/atencion/citas?fecha=&empleadoID=&estadoID=
router.get('/citas', verificarToken, async (req, res) => {
    const { fecha, empleadoID, estadoID } = req.query;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Fecha',      sql.Date, fecha      ? new Date(fecha) : null)
            .input('EmpleadoID', sql.Int,  empleadoID ? parseInt(empleadoID) : null)
            .input('EstadoID',   sql.Int,  estadoID   ? parseInt(estadoID)   : null)
            .execute('Agenda.SP_GestionCitas');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 3. CONFIRMAR CITA ═════════════════════════════════
// PUT /api/atencion/citas/:id/confirmar
router.put('/citas/:id/confirmar', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('CitaID', sql.Int, parseInt(req.params.id))
            .execute('Agenda.SP_ConfirmarCita');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 4. CREAR CITA ═════════════════════════════════════
// POST /api/atencion/citas
// POST /api/atencion/citas
router.post('/citas', verificarToken, async (req, res) => {
    const { clienteID, servicios, fechaInicio, estadoID, notas } = req.body;
    if (!clienteID || !servicios || !fechaInicio)
        return res.status(400).json({ error: 'clienteID, servicios y fechaInicio son requeridos' });
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('ClienteID',   sql.Int,          parseInt(clienteID))
            .input('FechaInicio', sql.NVarChar(30), fechaInicio ? fechaInicio.replace('T',' ').substring(0,19) : null)
            .input('Servicios',   sql.VarChar(500), servicios)
            .input('EstadoID',    sql.Int,          estadoID ? parseInt(estadoID) : 8)
            .input('Notas',       sql.VarChar(200), notas || null)
            .execute('Agenda.SP_CrearCitaRecepcion');
        res.json(r.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 5. EDITAR CITA ════════════════════════════════════
// PUT /api/atencion/citas/:id
// PUT /api/atencion/citas/:id
router.put('/citas/:id', verificarToken, async (req, res) => {
    const { estadoID, nuevaFecha } = req.body;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('CitaID',     sql.Int,      parseInt(req.params.id))
            .input('EstadoID',   sql.Int,      estadoID   ? parseInt(estadoID)   : null)
            .input('NuevaFecha', sql.NVarChar(30), nuevaFecha ? nuevaFecha.replace('T',' ').substring(0,19) : null)
            .execute('Agenda.SP_EditarCitaRecepcion');

        // Si se está completando la cita, guardar en MongoDB
        if (parseInt(estadoID) === 11) {
            try {
                const { getMongo } = require('../mongodb');
                const db   = getMongo();
                const pool2 = await poolPromise;
                const citaData = await pool2.request()
                    .input('CitaID', sql.Int, parseInt(req.params.id))
                    .query(`
                        SELECT cl.ClienteID, p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
                               p.Email AS EmailCliente, s.Nombre AS Servicio, s.DuracionMin,
                               pe.Nombre AS NombreEmpleado, pe.Apellido AS ApellidoEmpleado,
                               sp.Precio AS Total, cd.NotasTecnicas
                        FROM Agenda.Cita c
                        JOIN Ventas.Cliente cl ON cl.ClienteID = c.ClienteID
                        JOIN Personas.Persona p ON p.PersonaID = cl.ClienteID
                        JOIN Agenda.CitaServicio cs ON cs.CitaID = c.CitaID
                        JOIN Servicios.Servicio s ON s.ServicioID = cs.ServicioID
                        JOIN Personas.Persona pe ON pe.PersonaID = cs.EmpleadoID
                        LEFT JOIN Servicios.ServicioPrecio sp ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
                        LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID = cl.ClienteID
                        LEFT JOIN Agenda.Cita ci ON ci.CitaID = @CitaID
                        WHERE c.CitaID = @CitaID
                    `);
                const cita = citaData.recordset[0];
                
                if (cita) {
                    await db.collection('historial_clientes').updateOne(
                        { clienteId: cita.ClienteID },
                        {
                            $set: {
                                clienteId:         cita.ClienteID,
                                nombre:            cita.NombreCliente || '',
                                apellido:          cita.ApellidoCliente || '',
                                email:             cita.EmailCliente || '',
                                sucursal:          'Santa Cruz',
                                fechaUltimaVisita: new Date()
                            },
                            $inc: { totalVisitas: 1, totalGastado: parseFloat(cita.Total || 0) },
                            $push: {
                                historial: {
                                    fecha:               new Date(),
                                    servicio:            cita.Servicio || '',
                                    empleado:            cita.NombreEmpleado + ' ' + cita.ApellidoEmpleado,
                                    duracionMin:         cita.DuracionMin || 0,
                                    precio:              parseFloat(cita.Total || 0),
                                    productosUsados:     [],
                                    notasTecnicas:       cita.NotasTecnicas || '',
                                    reaccionesAlergicas: [],
                                    satisfaccion:        null
                                }
                            }
                        },
                        { upsert: true }
                    );
                }
            } catch(mongoErr) { console.error('MongoDB historial:', mongoErr.message); }
        }

        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 6. CANCELAR CITA ══════════════════════════════════
// PUT /api/atencion/citas/:id/cancelar
router.put('/citas/:id/cancelar', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('CitaID', sql.Int, parseInt(req.params.id))
            .execute('Agenda.SP_CancelarCitaRecepcion');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 7. CLIENTES ═══════════════════════════════════════
// GET /api/atencion/clientes?busqueda=&filtro=
router.get('/clientes', verificarToken, async (req, res) => {
    const { busqueda, filtro } = req.query;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Busqueda', sql.VarChar(100), busqueda || null)
            .input('Filtro',   sql.VarChar(20),  filtro   || null)
            .execute('Ventas.SP_ObtenerClientes');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 8. DETALLE DE CLIENTE ═════════════════════════════
// GET /api/atencion/clientes/:id
router.get('/clientes/:id', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ClienteID', sql.Int, parseInt(req.params.id))
            .execute('Ventas.SP_DetalleCliente');
        res.json({
            cliente:  result.recordsets[0][0] || null,
            historial: result.recordsets[1]   || []
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 9. REGISTRAR CLIENTE ══════════════════════════════
// POST /api/atencion/clientes
router.post('/clientes', verificarToken, async (req, res) => {
    const { nombre, apellido, telefono, email, alergias, contraindicaciones, notasTecnicas } = req.body;
    if (!nombre || !apellido || !telefono || !email)
        return res.status(400).json({ error: 'Nombre, apellido, teléfono y email son requeridos' });
    try {
        // Generar contraseña temporal: primeros 4 dígitos del teléfono + Coco!
        const digits = telefono.replace(/\D/g, '').replace(/^591/, '').substring(0, 4);
        const passTemp = digits + 'Coco!';
        const passHash = await bcrypt.hash(passTemp, 10);

        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Nombre',             sql.VarChar(100), nombre)
            .input('Apellido',           sql.VarChar(100), apellido)
            .input('Telefono',           sql.VarChar(20),  telefono)
            .input('Email',              sql.VarChar(100), email)
            .input('PassHash',           sql.VarChar(255), passHash)
            .input('Alergias',           sql.VarChar,      alergias           || null)
            .input('Contraindicaciones', sql.VarChar,      contraindicaciones || null)
            .input('NotasTecnicas',      sql.VarChar,      notasTecnicas      || null)
            .execute('Ventas.SP_RegistrarClienteRecepcion');

        res.json({
            ...result.recordset[0],
            contrasenaTemp: passTemp
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 10. REGISTRAR VENTA ═══════════════════════════════
// POST /api/atencion/ventas
router.post('/ventas', verificarToken, async (req, res) => {
    const { clienteID, empleadoID, metodoPagoID, monto, servicios, productos, descuentoPct, referencia, promocionID, descuentoMonto } = req.body;
    if (!clienteID || !metodoPagoID || !monto)
        return res.status(400).json({ error: 'clienteID, metodoPagoID y monto son requeridos' });
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('ClienteID',      sql.Int,           parseInt(clienteID))
            .input('EmpleadoID', sql.Int, empleadoID ? parseInt(empleadoID) : null)
            .input('MetodoPagoID',   sql.Int,           parseInt(metodoPagoID))
            .input('Monto',          sql.Decimal(10,2), parseFloat(monto))
            .input('Referencia',     sql.VarChar(100),  referencia || null)
            .input('Servicios',      sql.VarChar(2000), servicios  || null)
            .input('Productos',      sql.VarChar(2000), productos  || null)
            .input('DescuentoPct',   sql.Decimal(5,2),  parseFloat(descuentoPct   || 0))
            .input('DescuentoMonto', sql.Decimal(10,2), parseFloat(descuentoMonto || 0))
            .input('PromocionID',    sql.Int,           promocionID ? parseInt(promocionID) : null)
            .execute('Ventas.SP_RegistrarVenta');
        res.json(r.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 11. FACTURAS ══════════════════════════════════════
// GET /api/atencion/facturas?estado=
router.get('/facturas', verificarToken, async (req, res) => {
    try {
        const pool = await poolPromise;
        const r = await pool.request()
            .input('Estado',     sql.VarChar(20), req.query.estado     || null)
            .input('FechaDesde', sql.Date,        req.query.fechaDesde ? new Date(req.query.fechaDesde) : null)
            .input('FechaHasta', sql.Date,        req.query.fechaHasta ? new Date(req.query.fechaHasta) : null)
            .execute('Facturacion.SP_ObtenerFacturas');
        res.json(r.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 12. MARCAR FACTURA PAGADA ═════════════════════════
// PUT /api/atencion/facturas/:id/pagar
router.put('/facturas/:id/pagar', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('FacturaID', sql.Int, parseInt(req.params.id))
            .execute('Facturacion.SP_MarcarFacturaPagada');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 13. ANULAR FACTURA ════════════════════════════════
// PUT /api/atencion/facturas/:id/anular
router.put('/facturas/:id/anular', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('FacturaID', sql.Int, parseInt(req.params.id))
            .execute('Facturacion.SP_AnularFactura');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 14. APROBAR EXCEPCIÓN DE HORARIO ══════════════════
// PUT /api/atencion/excepciones/:id/aprobar
router.put('/excepciones/:id/aprobar', verificarToken, async (req, res) => {
    const { aprobado } = req.body;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ExcepcionID', sql.Int, parseInt(req.params.id))
            .input('Aprobado',    sql.Bit, aprobado ? 1 : 0)
            .execute('RRHH.SP_AprobarExcepcion');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 16. EMPLEADOS TÉCNICOS ════════════════════════════
// GET /api/atencion/empleados
router.get('/empleados', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .execute('RRHH.SP_ObtenerHorarioEmpleado');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 17. NOTIFICACIONES ════════════════════════════════
// GET /api/atencion/notificaciones
router.get('/notificaciones', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('PersonaID', sql.Int, req.usuario.personaID)
            .execute('Notificaciones.SP_ObtenerNotificacionesRecepcion');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 18. MARCAR NOTIFICACIÓN LEÍDA ═════════════════════
// PUT /api/atencion/notificaciones/:id/leer
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

// ══ 19. CATÁLOGO PARA COBRO ═══════════════════════════
// GET /api/atencion/catalogo
router.get('/catalogo', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('CategoriaID', sql.Int, null)
            .execute('Servicios.SP_ObtenerCatalogo');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 20. MÉTODOS DE PAGO ═══════════════════════════════
// GET /api/atencion/metodos-pago
router.get('/metodos-pago', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .query('SELECT MetodoPagoID, Nombre FROM Ventas.MetodoPago');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 21. PERFIL ════════════════════════════════════════
// GET /api/atencion/perfil
router.get('/perfil', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('PersonaID', sql.Int, req.usuario.personaID)
            .execute('Agenda.SP_ObtenerPerfilRecepcion');
        res.json(result.recordset[0] || null);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// PUT /api/atencion/perfil
router.put('/perfil', verificarToken, async (req, res) => {
    const { nombre, apellido, telefono, email, fechaNacimiento } = req.body;
    if (!nombre || !apellido || !telefono || !email)
        return res.status(400).json({ error: 'Faltan campos requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('PersonaID',       sql.Int,          req.usuario.personaID)
            .input('Nombre',          sql.VarChar(100),  nombre)
            .input('Apellido',        sql.VarChar(100),  apellido)
            .input('Telefono',        sql.VarChar(20),   telefono)
            .input('Email',           sql.VarChar(100),  email)
            .input('FechaNacimiento', sql.Date,          fechaNacimiento || null)
            .execute('Agenda.SP_ActualizarPerfilRecepcion');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});



// ══ EXCEPCIONES DE HORARIO ════════════════════════════
// GET /api/atencion/excepciones
router.get('/excepciones', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .execute('RRHH.SP_ListarExcepcionesPendientes');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// PUT /api/atencion/excepciones/:id/aprobar
router.put('/excepciones/:id/aprobar', verificarToken, async (req, res) => {
    const { aprobado } = req.body;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ExcepcionID', sql.Int, parseInt(req.params.id))
            .input('Aprobado',    sql.Bit, aprobado ? 1 : 0)
            .execute('RRHH.SP_AprobarExcepcion');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/atencion/productos
router.get('/productos', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .execute('Inventario.SP_ObtenerProductosVenta');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/atencion/promociones-activas
router.get('/promociones-activas', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .execute('Marketing.SP_ObtenerPromocionesActivas');
        const promociones = result.recordsets[0] || [];
        const servicios   = result.recordsets[1] || [];
        const cumpleanos  = result.recordsets[2] || [];

        // Agregar ServicioIDs a generales
        promociones.forEach(p => {
            p.ServicioIDs = servicios
                .filter(s => s.PromocionID === p.PromocionID)
                .map(s => s.ServicioID);
        });

        // Agregar promo cumpleaños siempre, con nota
        cumpleanos.forEach(p => {
            p.Nombre     = p.Nombre + ' 🎂';
            p.ServicioIDs = servicios
                .filter(s => s.PromocionID === p.PromocionID)
                .map(s => s.ServicioID);
            promociones.push(p);
        });

        res.json(promociones);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

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

// ══ SOLICITUDES ESPECIALES ════════════════════════════
router.get('/solicitudes', verificarToken, async (req, res) => {
    const { estado } = req.query;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Estado', sql.VarChar(20), estado || null)
            .execute('Agenda.SP_ObtenerSolicitudes');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/solicitudes/:id/aprobar', verificarToken, async (req, res) => {
    const { fechaConfirmada, empleadoID } = req.body;
    if (!fechaConfirmada) return res.status(400).json({ error: 'fechaConfirmada es requerida' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('SolicitudID',     sql.Int,          parseInt(req.params.id))
            .input('FechaConfirmada', sql.NVarChar(30),  fechaConfirmada.replace('T',' ').substring(0,19))
            .input('EmpleadoID',      sql.Int,           empleadoID ? parseInt(empleadoID) : null)
            .execute('Agenda.SP_AprobarSolicitud');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/solicitudes/:id/rechazar', verificarToken, async (req, res) => {
    const { motivoRechazo } = req.body;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('SolicitudID',   sql.Int,          parseInt(req.params.id))
            .input('MotivoRechazo', sql.VarChar(300),  motivoRechazo || null)
            .execute('Agenda.SP_RechazarSolicitud');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;