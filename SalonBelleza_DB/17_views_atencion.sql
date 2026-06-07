USE SalonBelleza_DB;
GO

-- MÓDULO ATENCIÓN

-- 1. Citas del día completas
CREATE VIEW Agenda.VW_CitasHoy AS
SELECT
    c.CitaID,
    c.ClienteID,
    p.Nombre            AS NombreCliente,
    p.Apellido          AS ApellidoCliente,
    p.Telefono          AS TelefonoCliente,
    cd.Alergias,
    c.FechaInicio,
    cs.CitaServicioID,
    cs.ServicioID,
    s.Nombre            AS Servicio,
    s.DuracionMin,
    cs.FechaInicioServicio,
    cs.FechaFinServicio,
    cs.EmpleadoID,
    emp.Nombre          AS NombreEmpleado,
    emp.Apellido        AS ApellidoEmpleado,
    ec.EstadoID,
    ec.Nombre           AS Estado,
    sp.Precio
FROM Agenda.Cita              c
JOIN Personas.Persona         p   ON p.PersonaID   = c.ClienteID
JOIN Agenda.CitaServicio      cs  ON cs.CitaID     = c.CitaID
JOIN Servicios.Servicio       s   ON s.ServicioID  = cs.ServicioID
JOIN Personas.Persona         emp ON emp.PersonaID = cs.EmpleadoID
JOIN Agenda.EstadoCita        ec  ON ec.EstadoID   = c.EstadoID
JOIN Servicios.ServicioPrecio sp  ON sp.ServicioID = s.ServicioID
                                  AND sp.FechaFin  IS NULL
LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID = c.ClienteID
WHERE CAST(c.FechaInicio AS DATE) = CAST(GETDATE() AS DATE)
  AND c.EstadoID NOT IN (5, 6);
GO

-- 2. Solicitudes especiales pendientes
CREATE VIEW Agenda.VW_SolicitudesPendientes AS
SELECT
    s.SolicitudID,
    s.ClienteID,
    p.Nombre            AS NombreCliente,
    p.Apellido          AS ApellidoCliente,
    p.Telefono,
    s.FechaSolicitada,
    s.Motivo,
    s.Estado,
    s.FechaCreacion
FROM Agenda.SolicitudEspecial s
JOIN Ventas.Cliente            c  ON c.ClienteID  = s.ClienteID
JOIN Personas.Persona          p  ON p.PersonaID  = s.ClienteID
WHERE s.Estado = 'pendiente';
GO

-- 3. Excepciones pendientes para aprobar
DROP VIEW IF EXISTS RRHH.VW_ExcepcionesPendientes;
GO

CREATE VIEW RRHH.VW_ExcepcionesPendientes AS
SELECT
    he.ExcepcionID,
    he.EmpleadoID,
    p.Nombre            AS NombreEmpleado,
    p.Apellido          AS ApellidoEmpleado,
    r.NombreRol,
    he.Fecha,
    he.Disponible,
    he.Motivo,
    he.TipoSolicitud
FROM RRHH.HorarioExcepcion he
JOIN Personas.Persona       p  ON p.PersonaID  = he.EmpleadoID
JOIN RRHH.EmpleadoRol       er ON er.EmpleadoID = he.EmpleadoID
JOIN RRHH.Rol               r  ON r.RolID       = er.RolID
WHERE he.Aprobado = 0
  AND he.Fecha   >= CAST(GETDATE() AS DATE);
GO