// src/routes/duena.js

const express              = require('express');
const router               = express.Router();
const jwt                  = require('jsonwebtoken');
const { sql, poolPromise } = require('../db');

// ══ HELPER: Sincronizar roles de seguridad + dedup ════
async function sincronizarRoles(pool) {
    await pool.request().execute('RRHH.SP_SincronizarRolesSeguridad');
    await pool.request().query(`
        WITH CTE AS (
            SELECT UsuarioID, RolID,
                   ROW_NUMBER() OVER (PARTITION BY UsuarioID, RolID ORDER BY UsuarioID) AS rn
            FROM Seguridad.UsuarioRol
        )
        DELETE FROM CTE WHERE rn > 1
    `);
}

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

// ══ 1. PANEL EJECUTIVO ════════════════════════════════
router.get('/panel', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request().execute('Duena.SP_ResumenEjecutivo');
        res.json({
            ingresos:      result.recordsets[0][0] || {},
            citas:         result.recordsets[1][0] || {},
            clientes:      result.recordsets[2][0] || {},
            equipo:        result.recordsets[3]    || [],
            ingresosMes:   result.recordsets[4]    || [],
            nomina:        result.recordsets[5][0] || {},
            topEstilistas: result.recordsets[6]    || []
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 2. REPORTE ANUAL ══════════════════════════════════
router.get('/reporte', verificarToken, async (req, res) => {
    const { anio } = req.query;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Anio', sql.Int, anio ? parseInt(anio) : null)
            .execute('Duena.SP_ReporteAnual');
        res.json({
            porMes:  result.recordsets[0]    || [],
            nomina:  result.recordsets[1]    || [],
            totales: result.recordsets[2][0] || {}
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 3. NÓMINA COMPLETA ════════════════════════════════
router.get('/nomina', verificarToken, async (req, res) => {
    const { anio, mes } = req.query;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Anio', sql.Int, anio ? parseInt(anio) : null)
            .input('Mes',  sql.Int, mes  ? parseInt(mes)  : null)
            .execute('Duena.SP_VerTodosLosSueldos');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 4. PAGAR AL ADMINISTRADOR ═════════════════════════
router.post('/nomina/pagar', verificarToken, async (req, res) => {
    const { empleadoID, periodo, montoPagado } = req.body;
    if (!empleadoID || !periodo || !montoPagado)
        return res.status(400).json({ error: 'empleadoID, periodo y montoPagado son requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID',  sql.Int,           parseInt(empleadoID))
            .input('Periodo',     sql.VarChar(7),     periodo)
            .input('MontoPagado', sql.Decimal(10,2),  parseFloat(montoPagado))
            .execute('RRHH.SP_RegistrarPagoNominaDuena');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 5. REPORTE DE VENTAS ══════════════════════════════
router.get('/reportes-ventas', verificarToken, async (req, res) => {
    const { fechaInicio, fechaFin } = req.query;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('FechaInicio', sql.Date, fechaInicio ? new Date(fechaInicio) : null)
            .input('FechaFin',    sql.Date, fechaFin    ? new Date(fechaFin)    : null)
            .execute('Duena.SP_ReporteVentas');
        res.json({
            porEmpleado: result.recordsets[0]    || [],
            porServicio: result.recordsets[1]    || [],
            totales:     result.recordsets[2][0] || {}
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 6. EMPLEADOS ══════════════════════════════════════
router.get('/empleados', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request().execute('Duena.SP_ListarEmpleados');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/empleados/:id', verificarToken, async (req, res) => {
    const { nombre, apellido, telefono, email, fechaNacimiento,
            activo, nuevoSueldo, nuevoPct, roleIDs } = req.body;
    if (!nombre || !apellido || !telefono || !email)
        return res.status(400).json({ error: 'Faltan campos requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID',      sql.Int,           parseInt(req.params.id))
            .input('Nombre',          sql.VarChar(100),   nombre)
            .input('Apellido',        sql.VarChar(100),   apellido)
            .input('Telefono',        sql.VarChar(20),    telefono)
            .input('Email',           sql.VarChar(100),   email)
            .input('FechaNacimiento', sql.Date,           fechaNacimiento || null)
            .input('Activo',          sql.Bit,            activo !== undefined ? (activo ? 1 : 0) : 1)
            .input('NuevoSueldo',     sql.Decimal(10,2),  nuevoSueldo ? parseFloat(nuevoSueldo) : null)
            .input('NuevoPct',        sql.Decimal(5,2),   nuevoPct    ? parseFloat(nuevoPct)    : null)
            .input('RoleIDs',         sql.VarChar(100),   roleIDs     || null)
            .execute('RRHH.SP_ActualizarEmpleado');

        await sincronizarRoles(pool);

        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.get('/empleados/:id/roles', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID', sql.Int, parseInt(req.params.id))
            .execute('RRHH.SP_ObtenerRolesEmpleado');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.get('/roles-laborales', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .query('SELECT RolID, NombreRol FROM RRHH.Rol ORDER BY RolID');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 7. REGISTRAR ADMINISTRADOR ════════════════════════
router.post('/empleados/admin', verificarToken, async (req, res) => {
    const { nombre, apellido, telefono, email, fechaContrato, sueldoBase } = req.body;
    if (!nombre || !apellido || !telefono || !email || !fechaContrato || !sueldoBase)
        return res.status(400).json({ error: 'Faltan campos requeridos' });
    try {
        const bcrypt   = require('bcrypt');
        const digits   = telefono.replace(/\D/g, '').replace(/^591/, '').substring(0, 4);
        const passTemp = digits + 'Coco!';
        const passHash = await bcrypt.hash(passTemp, 10);

        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Nombre',        sql.VarChar(100),  nombre)
            .input('Apellido',      sql.VarChar(100),  apellido)
            .input('Telefono',      sql.VarChar(20),   telefono)
            .input('Email',         sql.VarChar(100),  email)
            .input('PassHash',      sql.VarChar(255),  passHash)
            .input('FechaContrato', sql.Date,          new Date(fechaContrato))
            .input('SueldoBase',    sql.Decimal(10,2), parseFloat(sueldoBase))
            .execute('Duena.SP_RegistrarAdmin');

        await sincronizarRoles(pool);

        res.json({ ...result.recordset[0], contrasenaTemp: passTemp });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 8. ACTIVAR/DESACTIVAR EMPLEADO ═══════════════════
router.put('/empleados/:id/estado', verificarToken, async (req, res) => {
    const { activo } = req.body;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('EmpleadoID', sql.Int, parseInt(req.params.id))
            .input('Activo',     sql.Bit, activo ? 1 : 0)
            .execute('Duena.SP_CambiarEstadoEmpleado');

        await sincronizarRoles(pool);

        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 9. SERVICIOS ══════════════════════════════════════
router.get('/servicios', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request().execute('Servicios.SP_ListarServicios');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.get('/subcategorias', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request().execute('Servicios.SP_ListarSubcategorias');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/servicios', verificarToken, async (req, res) => {
    const { nombre, descripcion, duracionMin, subcategoriaID, precio } = req.body;
    if (!nombre || !duracionMin || !subcategoriaID || !precio)
        return res.status(400).json({ error: 'Faltan campos requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Nombre',         sql.VarChar(100),  nombre)
            .input('Descripcion',    sql.VarChar(300),  descripcion || null)
            .input('DuracionMin',    sql.Int,           parseInt(duracionMin))
            .input('SubcategoriaID', sql.Int,           parseInt(subcategoriaID))
            .input('Precio',         sql.Decimal(10,2), parseFloat(precio))
            .execute('Servicios.SP_CrearServicio');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/servicios/:id', verificarToken, async (req, res) => {
    const { nombre, descripcion, duracionMin, activo } = req.body;
    if (!nombre || !duracionMin) return res.status(400).json({ error: 'Faltan campos requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ServicioID',  sql.Int,           parseInt(req.params.id))
            .input('Nombre',      sql.VarChar(100),   nombre)
            .input('Descripcion', sql.VarChar(300),   descripcion || null)
            .input('DuracionMin', sql.Int,            parseInt(duracionMin))
            .input('Activo',      sql.Bit,            activo !== undefined ? (activo ? 1 : 0) : 1)
            .execute('Servicios.SP_EditarServicio');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/servicios/:id/precio', verificarToken, async (req, res) => {
    const { nuevoPrecio } = req.body;
    if (!nuevoPrecio) return res.status(400).json({ error: 'nuevoPrecio es requerido' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ServicioID',  sql.Int,           parseInt(req.params.id))
            .input('NuevoPrecio', sql.Decimal(10,2),  parseFloat(nuevoPrecio))
            .execute('Servicios.SP_ActualizarPrecio');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 10. INVENTARIO ════════════════════════════════════
router.get('/inventario', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request().execute('Inventario.SP_ObtenerInventario');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/inventario/:id/stock', verificarToken, async (req, res) => {
    const { cantidad, tipo, motivo } = req.body;
    if (!cantidad || !tipo) return res.status(400).json({ error: 'cantidad y tipo son requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ProductoID', sql.Int,          parseInt(req.params.id))
            .input('Cantidad',   sql.Int,           parseInt(cantidad))
            .input('Tipo',       sql.VarChar(20),   tipo)
            .input('Motivo',     sql.VarChar(200),  motivo || null)
            .execute('Inventario.SP_AjustarStock');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 11. PROVEEDORES ═══════════════════════════════════
router.get('/proveedores', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request().execute('Inventario.SP_ListarProveedores');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/proveedores', verificarToken, async (req, res) => {
    const { nombre, telefono, email } = req.body;
    if (!nombre) return res.status(400).json({ error: 'Nombre es requerido' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Nombre',   sql.VarChar(100), nombre)
            .input('Telefono', sql.VarChar(20),  telefono || null)
            .input('Email',    sql.VarChar(100), email    || null)
            .execute('Inventario.SP_CrearProveedor');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/proveedores/:id', verificarToken, async (req, res) => {
    const { nombre, telefono, email } = req.body;
    if (!nombre) return res.status(400).json({ error: 'Nombre es requerido' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ProveedorID', sql.Int,           parseInt(req.params.id))
            .input('Nombre',      sql.VarChar(100),   nombre)
            .input('Telefono',    sql.VarChar(20),    telefono || null)
            .input('Email',       sql.VarChar(100),   email    || null)
            .execute('Inventario.SP_EditarProveedor');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 12. PRODUCTOS ═════════════════════════════════════
router.post('/productos', verificarToken, async (req, res) => {
    const { nombre, stockActual, stockMinimo, unidadMedida, precio, proveedorID } = req.body;
    if (!nombre || !precio) return res.status(400).json({ error: 'Nombre y precio son requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Nombre',       sql.VarChar(100),  nombre)
            .input('StockActual',  sql.Int,           parseInt(stockActual  || 0))
            .input('StockMinimo',  sql.Int,           parseInt(stockMinimo  || 5))
            .input('UnidadMedida', sql.VarChar(20),   unidadMedida || null)
            .input('Precio',       sql.Decimal(10,2), parseFloat(precio))
            .input('ProveedorID',  sql.Int,           proveedorID ? parseInt(proveedorID) : null)
            .execute('Inventario.SP_CrearProducto');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/productos/:id', verificarToken, async (req, res) => {
    const { nombre, stockMinimo, unidadMedida, nuevoPrecio, proveedorID } = req.body;
    if (!nombre) return res.status(400).json({ error: 'Nombre es requerido' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('ProductoID',  sql.Int,           parseInt(req.params.id))
            .input('Nombre',      sql.VarChar(100),   nombre)
            .input('StockMinimo', sql.Int,            parseInt(stockMinimo || 5))
            .input('UnidadMedida',sql.VarChar(20),    unidadMedida || null)
            .input('NuevoPrecio', sql.Decimal(10,2),  nuevoPrecio ? parseFloat(nuevoPrecio) : null)
            .input('ProveedorID', sql.Int,            proveedorID ? parseInt(proveedorID) : null)
            .execute('Inventario.SP_EditarProducto');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 13. PROMOCIONES ═══════════════════════════════════
router.get('/promociones', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request().execute('Marketing.SP_ListarPromociones');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/promociones', verificarToken, async (req, res) => {
    const { nombre, descripcion, descuento, fechaInicio, fechaFin, servicioIDs } = req.body;
    if (!nombre || !descuento || !fechaInicio || !fechaFin)
        return res.status(400).json({ error: 'Faltan campos requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Nombre',      sql.VarChar(100), nombre)
            .input('Descripcion', sql.VarChar(300), descripcion || null)
            .input('Descuento',   sql.Decimal(5,2), parseFloat(descuento))
            .input('FechaInicio', sql.Date,         new Date(fechaInicio))
            .input('FechaFin',    sql.Date,         new Date(fechaFin))
            .input('ServicioIDs', sql.VarChar(500), servicioIDs || null)
            .execute('Marketing.SP_CrearPromocion');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/promociones/:id', verificarToken, async (req, res) => {
    const { nombre, descripcion, descuento, fechaInicio, fechaFin, activo, servicioIDs } = req.body;
    if (!nombre || !descuento || !fechaInicio || !fechaFin)
        return res.status(400).json({ error: 'Faltan campos requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('PromocionID',  sql.Int,           parseInt(req.params.id))
            .input('Nombre',       sql.VarChar(100),   nombre)
            .input('Descripcion',  sql.VarChar(300),   descripcion || null)
            .input('Descuento',    sql.Decimal(5,2),   parseFloat(descuento))
            .input('FechaInicio',  sql.Date,           new Date(fechaInicio))
            .input('FechaFin',     sql.Date,           new Date(fechaFin))
            .input('Activo',       sql.Bit,            activo !== undefined ? (activo ? 1 : 0) : 1)
            .input('ServicioIDs',  sql.VarChar(500),   servicioIDs || null)
            .execute('Marketing.SP_EditarPromocion');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 14. PERFIL ════════════════════════════════════════
router.get('/perfil', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('PersonaID', sql.Int, req.usuario.personaID)
            .execute('Duena.SP_ObtenerPerfil');
        res.json(result.recordset[0] || null);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/perfil', verificarToken, async (req, res) => {
    const { nombre, apellido, telefono, email, fechaNacimiento } = req.body;
    if (!nombre || !apellido || !telefono || !email)
        return res.status(400).json({ error: 'Faltan campos requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('PersonaID',       sql.Int,           req.usuario.personaID)
            .input('Nombre',          sql.VarChar(100),   nombre)
            .input('Apellido',        sql.VarChar(100),   apellido)
            .input('Telefono',        sql.VarChar(20),    telefono)
            .input('Email',           sql.VarChar(100),   email)
            .input('FechaNacimiento', sql.Date,           fechaNacimiento || null)
            .execute('Duena.SP_ActualizarPerfil');
        res.json(result.recordset[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 15. NOTIFICACIONES ════════════════════════════════
router.get('/notificaciones', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('PersonaID', sql.Int, req.usuario.personaID)
            .execute('Notificaciones.SP_ObtenerNotificaciones');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

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

// ══ 16. CLIENTES GLOBAL ═══════════════════════════════
router.get('/clientes', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request().execute('Duena.SP_ListarClientes');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 17. CITAS DEL DÍA GLOBAL ═════════════════════════
router.get('/citas', verificarToken, async (req, res) => {
    try {
        const pool   = await poolPromise;
        const result = await pool.request().execute('Duena.SP_CitasDelDia');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ══ 18. FACTURAS GLOBAL ═══════════════════════════════
router.get('/facturas', verificarToken, async (req, res) => {
    const { fechaInicio, fechaFin } = req.query;
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('FechaInicio', sql.Date, fechaInicio ? new Date(fechaInicio) : null)
            .input('FechaFin',    sql.Date, fechaFin    ? new Date(fechaFin)    : null)
            .execute('Duena.SP_ListarFacturas');
        res.json(result.recordset);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;