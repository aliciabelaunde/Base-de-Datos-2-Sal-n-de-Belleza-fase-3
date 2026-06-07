const express = require('express');
const bcrypt  = require('bcrypt');
const jwt     = require('jsonwebtoken');
const { sql, poolPromise } = require('../db');

const router = express.Router();

// ── REGISTRO ──────────────────────────────────────────
router.post('/register', async (req, res) => {
  const { nombre, apellido, telefono, email, password } = req.body;

  try {
    const pool = await poolPromise;

    // Encriptar contraseña antes de enviar al SP
    const hash = await bcrypt.hash(password, 10);

    // Llamar al stored procedure
    await pool.request()
      .input('Nombre',   sql.VarChar, nombre)
      .input('Apellido', sql.VarChar, apellido)
      .input('Telefono', sql.VarChar, telefono)
      .input('Email',    sql.VarChar, email)
      .input('PassHash', sql.VarChar, hash)
      .execute('Seguridad.SP_RegistrarCliente');

    res.json({ message: 'Cuenta creada exitosamente' });

  } catch (err) {
    console.error(err);
    // El SP devuelve mensajes específicos
    if (err.message.includes('correo')) {
      return res.status(400).json({ error: 'Este correo ya está registrado' });
    }
    if (err.message.includes('teléfono')) {
      return res.status(400).json({ error: 'Este teléfono ya está registrado' });
    }
    res.status(500).json({ error: 'Error al crear la cuenta' });
  }
});

// ── LOGIN ─────────────────────────────────────────────
// ── LOGIN ─────────────────────────────────────────────
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  try {
    const pool = await poolPromise;

    const result = await pool.request()
      .input('Email', sql.VarChar, email)
      .execute('Seguridad.SP_Login');

    if (result.recordset.length === 0) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
    }

    const user  = result.recordset[0];
    const match = await bcrypt.compare(password, user.PasswordHash);

    if (!match) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
    }

    // Obtener TODOS los roles del usuario
    const rolesResult = await pool.request()
      .input('UsuarioID', sql.Int, user.UsuarioID)
      .query(`
        SELECT r.Nombre AS Rol
        FROM Seguridad.UsuarioRol ur
        JOIN Seguridad.Rol r ON r.RolID = ur.RolID
        WHERE ur.UsuarioID = @UsuarioID
      `);

    const roles = rolesResult.recordset.map(function(r) {
      return r.Rol.normalize('NFC');
    });

    const rolPrincipal = roles[0];

    const token = jwt.sign(
      {
        usuarioID: user.UsuarioID,
        personaID: user.PersonaID,
        nombre:    user.Nombre,
        rol:       rolPrincipal
      },
      process.env.JWT_SECRET,
      { expiresIn: '8h' }
    );

    const rutas = {

      'Dueño/a':            '/pages/dashboard-duena.html',
      'Administrador':      '/pages/dashboard-admin.html',
      'Cliente':            '/pages/dashboard-cliente.html',
      'Atención y soporte': '/pages/dashboard-atencion.html',
      'Personal técnico':   '/pages/dashboard-personal.html'
    };

    // Si tiene más de un rol → devolver todos para que el frontend muestre selector
if (roles.length > 1) {
    return res.json({
        // NO incluir token aquí — se generará cuando el usuario elija rol
        nombre:      user.Nombre,
        apellido:    user.Apellido,
        personaID:   user.PersonaID,
        passwordHash: user.PasswordHash, // necesario para revalidar
        roles:       roles,
        multiroles:  true,
        rutasPosibles: roles.map(function(r) {
            return { rol: r, ruta: rutas[r] || '/pages/dashboard-cliente.html' };
        })
    });
}

// POST /api/auth/elegir-rol
router.post('/elegir-rol', async (req, res) => {
    const { email, password, rolElegido } = req.body;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('Email', sql.VarChar, email)
            .execute('Seguridad.SP_Login');

        if (!result.recordset.length)
            return res.status(401).json({ error: 'Usuario no encontrado' });

        const user  = result.recordset[0];
        const match = await bcrypt.compare(password, user.PasswordHash);
        if (!match) return res.status(401).json({ error: 'Credenciales inválidas' });

        const rutas = {
            'Dueño/a':            '/pages/dashboard-duena.html',
            'Administrador':      '/pages/dashboard-admin.html',
            'Cliente':            '/pages/dashboard-cliente.html',
            'Atención y soporte': '/pages/dashboard-atencion.html',
            'Personal técnico':   '/pages/dashboard-personal.html'
        };

        const token = jwt.sign(
            {
                usuarioID: user.UsuarioID,
                personaID: user.PersonaID,
                nombre:    user.Nombre,
                rol:       rolElegido
            },
            process.env.JWT_SECRET,
            { expiresIn: '8h' }
        );

        res.json({
            token,
            rol:      rolElegido,
            nombre:   user.Nombre,
            apellido: user.Apellido,
            personaID: user.PersonaID,
            ruta:     rutas[rolElegido] || '/pages/dashboard-cliente.html'
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

    // Log de auditoría en MongoDB
    try {
        const { getMongo } = require('../mongodb');
        const db = getMongo();
        await db.collection('logs_auditoria').insertOne({
            fecha:    new Date(),
            accion:   'login',
            usuario:  email,
            rol:      rolPrincipal,
            sucursal: 'Cochabamba',
            ip:       req.headers['x-forwarded-for'] || req.socket.remoteAddress,
            detalle:  'Inicio de sesión exitoso'
        });
    } catch(mongoErr) { console.error('MongoDB log:', mongoErr.message); }

    // Un solo rol → redirigir directo
    res.json({
      token,
      rol:       rolPrincipal,
      nombre:    user.Nombre,
      apellido:  user.Apellido,
      personaID: user.PersonaID,
      ruta:      rutas[rolPrincipal] || '/pages/dashboard-cliente.html'
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al iniciar sesión' });
  }
});

// POST /api/auth/elegir-rol
router.post('/elegir-rol', async (req, res) => {
    const { email, password, rolElegido } = req.body;
    if (!email || !password || !rolElegido)
        return res.status(400).json({ error: 'Faltan campos requeridos' });
    try {
        const pool   = await poolPromise;
        const result = await pool.request()
            .input('Email', sql.VarChar, email)
            .execute('Seguridad.SP_Login');

        if (!result.recordset.length)
            return res.status(401).json({ error: 'Usuario no encontrado' });

        const user  = result.recordset[0];
        const match = await bcrypt.compare(password, user.PasswordHash);
        if (!match) return res.status(401).json({ error: 'Credenciales inválidas' });

        const rutas = {
            'Dueño/a':            '/pages/dashboard-duena.html',
            'Administrador':      '/pages/dashboard-admin.html',
            'Cliente':            '/pages/dashboard-cliente.html',
            'Atención y soporte': '/pages/dashboard-atencion.html',
            'Personal técnico':   '/pages/dashboard-personal.html'
        };

        const token = jwt.sign(
            {
                usuarioID: user.UsuarioID,
                personaID: user.PersonaID,
                nombre:    user.Nombre,
                rol:       rolElegido
            },
            process.env.JWT_SECRET,
            { expiresIn: '8h' }
        );

        res.json({
            token,
            rol:       rolElegido,
            nombre:    user.Nombre,
            apellido:  user.Apellido,
            personaID: user.PersonaID,
            ruta:      rutas[rolElegido] || '/pages/dashboard-cliente.html'
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;