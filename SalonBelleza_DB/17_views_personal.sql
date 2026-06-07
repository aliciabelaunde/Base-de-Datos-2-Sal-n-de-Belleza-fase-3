USE SalonBelleza_DB;
GO

-- MÓDULO PERSONAL TÉCNICO

-- 1. Agenda por empleado
CREATE VIEW Agenda.VW_AgendaHoyEmpleado AS
SELECT
    cs.EmpleadoID,
    c.CitaID,
    c.ClienteID,
    p.Nombre            AS NombreCliente,
    p.Apellido          AS ApellidoCliente,
    s.ServicioID,
    s.Nombre            AS Servicio,
    s.DuracionMin,
    cs.FechaInicioServicio,
    cs.FechaFinServicio,
    cs.Orden,
    cs.EsParalelo,
    ec.EstadoID,
    ec.Nombre           AS Estado,
    sp.Precio,
    cd.Alergias,
    cd.Contraindicaciones,
    cd.NotasTecnicas
FROM Agenda.CitaServicio      cs
JOIN Agenda.Cita              c  ON c.CitaID      = cs.CitaID
JOIN Personas.Persona         p  ON p.PersonaID   = c.ClienteID
JOIN Servicios.Servicio       s  ON s.ServicioID  = cs.ServicioID
JOIN Agenda.EstadoCita        ec ON ec.EstadoID   = c.EstadoID
JOIN Servicios.ServicioPrecio sp ON sp.ServicioID = s.ServicioID
                                AND sp.FechaFin  IS NULL
LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID = c.ClienteID
WHERE CAST(cs.FechaInicioServicio AS DATE) = CAST(GETDATE() AS DATE)
  AND c.EstadoID NOT IN (5, 6);
GO

-- 2. Sueldo vigente por empleado
CREATE VIEW RRHH.VW_SueldoVigente AS
SELECT
    e.EmpleadoID,
    p.Nombre,
    p.Apellido,
    r.NombreRol,
    es.SueldoBase,
    es.FechaInicio  AS SueldoDesde,
    ec.Porcentaje   AS PorcentajeComision,
    ec.FechaInicio  AS ComisionDesde
FROM RRHH.Empleado           e
JOIN Personas.Persona         p  ON p.PersonaID  = e.EmpleadoID
JOIN RRHH.EmpleadoRol         er ON er.EmpleadoID = e.EmpleadoID
JOIN RRHH.Rol                 r  ON r.RolID       = er.RolID
JOIN RRHH.EmpleadoSueldo      es ON es.EmpleadoID = e.EmpleadoID
                                AND es.FechaFin  IS NULL
JOIN RRHH.EmpleadoComision    ec ON ec.EmpleadoID = e.EmpleadoID
                                AND ec.FechaFin  IS NULL
WHERE e.Activo = 1;
GO