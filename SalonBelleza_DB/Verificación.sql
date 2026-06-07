-- Verificar que el cliente fue creado correctamente
SELECT
    p.PersonaID,
    p.Nombre + ' ' + p.Apellido AS NombreCompleto,
    p.Email,
    p.Telefono,
    p.FechaRegistro,
    u.Username,
    u.Activo AS CuentaActiva,
    sr.Nombre AS RolSeguridad
FROM Personas.Persona p
JOIN Seguridad.Usuario u ON u.PersonaID = p.PersonaID
JOIN Seguridad.UsuarioRol ur ON ur.UsuarioID = u.UsuarioID
JOIN Seguridad.Rol sr ON sr.RolID = ur.RolID
JOIN Ventas.Cliente cl ON cl.ClienteID = p.PersonaID
WHERE p.Email = 'sofia@test.com';

-- Verificar que el empleado fue registrado con todos sus datos
SELECT
    p.PersonaID AS EmpleadoID,
    p.Nombre + ' ' + p.Apellido AS NombreCompleto,
    p.Email,
    r.NombreRol AS RolLaboral,
    sr.Nombre AS RolSeguridad,
    es.SueldoBase,
    ec.Porcentaje AS ComisionPct,
    COUNT(h.HorarioID) AS DiasHorario,
    e.FechaContratacion
FROM Personas.Persona p
JOIN RRHH.Empleado e ON e.EmpleadoID = p.PersonaID
JOIN RRHH.EmpleadoRol er ON er.EmpleadoID = p.PersonaID
JOIN RRHH.Rol r ON r.RolID = er.RolID
JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID = p.PersonaID AND es.FechaFin IS NULL
JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID = p.PersonaID AND ec.FechaFin IS NULL
JOIN RRHH.HorarioEmpleado h ON h.EmpleadoID = p.PersonaID
JOIN Seguridad.Usuario u ON u.PersonaID = p.PersonaID
JOIN Seguridad.UsuarioRol ur ON ur.UsuarioID = u.UsuarioID
JOIN Seguridad.Rol sr ON sr.RolID = ur.RolID
WHERE p.Email = 'maria@coco.com'
GROUP BY p.PersonaID, p.Nombre, p.Apellido, p.Email,
         r.NombreRol, sr.Nombre, es.SueldoBase,
         ec.Porcentaje, e.FechaContratacion;

-- Verificar que la cita fue reservada correctamente
SELECT
    c.CitaID,
    p.Nombre + ' ' + p.Apellido AS Cliente,
    s.Nombre AS Servicio,
    emp.Nombre + ' ' + emp.Apellido AS Empleado,
    r.NombreRol AS RolEmpleado,
    CONVERT(VARCHAR(10), cs.FechaInicioServicio, 103) AS Fecha,
    CONVERT(VARCHAR(5),  cs.FechaInicioServicio, 108) AS HoraInicio,
    CONVERT(VARCHAR(5),  cs.FechaFinServicio,    108) AS HoraFin,
    s.DuracionMin AS DuracionMin,
    sp.Precio,
    ce.TipoAsignacion,
    ec.Nombre AS Estado
FROM Agenda.Cita c
JOIN Personas.Persona p ON p.PersonaID = c.ClienteID
JOIN Agenda.CitaServicio cs ON cs.CitaID = c.CitaID
JOIN Servicios.Servicio s ON s.ServicioID = cs.ServicioID
JOIN Personas.Persona emp ON emp.PersonaID = cs.EmpleadoID
JOIN RRHH.EmpleadoRol er ON er.EmpleadoID = emp.PersonaID
JOIN RRHH.Rol r ON r.RolID = er.RolID
JOIN Agenda.CitaEmpleado ce ON ce.CitaID = c.CitaID AND ce.EmpleadoID = cs.EmpleadoID
JOIN Agenda.EstadoCita ec ON ec.EstadoID = c.EstadoID
JOIN Servicios.ServicioPrecio sp ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
WHERE c.CitaID = (SELECT MAX(CitaID) FROM Agenda.Cita);

-- Verificar que NO se puede crear una cita en un horario ya ocupado
-- (muestra los conflictos existentes para ese empleado y fecha)
SELECT
    emp.Nombre + ' ' + emp.Apellido AS Empleado,
    s.Nombre AS Servicio,
    CONVERT(VARCHAR(5), cs.FechaInicioServicio, 108) AS HoraInicio,
    CONVERT(VARCHAR(5), cs.FechaFinServicio,    108) AS HoraFin,
    ec.Nombre AS Estado
FROM Agenda.CitaServicio cs
JOIN Agenda.Cita c ON c.CitaID = cs.CitaID
JOIN Personas.Persona emp ON emp.PersonaID = cs.EmpleadoID
JOIN Servicios.Servicio s ON s.ServicioID = cs.ServicioID
JOIN Agenda.EstadoCita ec ON ec.EstadoID = c.EstadoID
WHERE cs.EmpleadoID = 7
  AND CAST(cs.FechaInicioServicio AS DATE) = '2026-04-14'
  AND c.EstadoID NOT IN (12, 13)
ORDER BY cs.FechaInicioServicio;

-- Verificar que el día libre bloquea la agenda
-- (empleado con excepción aprobada no debe aparecer disponible)
SELECT
    p.Nombre + ' ' + p.Apellido AS Empleado,
    CONVERT(VARCHAR(10), he.Fecha, 103) AS FechaLibre,
    he.Motivo,
    he.Estado,
    ISNULL((
        SELECT COUNT(*) FROM Agenda.CitaServicio cs
        JOIN Agenda.Cita c ON c.CitaID = cs.CitaID
        WHERE cs.EmpleadoID = he.EmpleadoID
          AND CAST(cs.FechaInicioServicio AS DATE) = he.Fecha
          AND c.EstadoID NOT IN (12, 13)
    ), 0) AS CitasActivasEseDia
FROM RRHH.HorarioExcepcion he
JOIN Personas.Persona p ON p.PersonaID = he.EmpleadoID
WHERE he.Estado = 'Aprobada'
  AND he.Disponible = 0
ORDER BY he.Fecha;

-- Verificar que la venta fue registrada con factura y pago
SELECT
    v.VentaID,
    p.Nombre + ' ' + p.Apellido AS Cliente,
    v.Fecha AS FechaVenta,
    v.Estado AS EstadoVenta,
    f.NumeroFactura,
    f.Estado AS EstadoFactura,
    mp.Nombre AS MetodoPago,
    pg.Monto AS MontoPagado,
    ISNULL(v.DescuentoPct, 0) AS DescuentoPct,
    ISNULL(v.DescuentoMonto, 0) AS DescuentoMonto
FROM Ventas.Venta v
JOIN Personas.Persona p ON p.PersonaID = v.ClienteID
JOIN Facturacion.Factura f ON f.VentaID = v.VentaID
JOIN Ventas.Pago pg ON pg.VentaID = v.VentaID
JOIN Ventas.MetodoPago mp ON mp.MetodoPagoID = pg.MetodoPagoID
WHERE v.VentaID = (SELECT MAX(VentaID) FROM Ventas.Venta);

-- Verificar el detalle de la última venta (servicios + empleado por servicio)
SELECT
    vds.VentaDetalleServicioID,
    s.Nombre AS Servicio,
    vds.Cantidad,
    vds.PrecioUnitario,
    vds.Cantidad * vds.PrecioUnitario AS Subtotal,
    emp.Nombre + ' ' + emp.Apellido AS EmpleadoQueAtendio,
    ec.Porcentaje AS ComisionPct,
    vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0 AS ComisionGenerada
FROM Ventas.VentaDetalleServicio vds
JOIN Servicios.Servicio s ON s.ServicioID = vds.ServicioID
JOIN Personas.Persona emp ON emp.PersonaID = vds.EmpleadoID
JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID = vds.EmpleadoID AND ec.FechaFin IS NULL
WHERE vds.VentaID = (SELECT MAX(VentaID) FROM Ventas.Venta);

-- Verificar que el stock bajó tras registrar una venta con productos
SELECT
    pr.ProductoID,
    pr.Nombre AS Producto,
    pr.StockActual,
    pr.StockMinimo,
    CASE
        WHEN pr.StockActual <= 0 THEN '⚠ SIN STOCK'
        WHEN pr.StockActual <= pr.StockMinimo THEN '⚠ STOCK BAJO'
        ELSE 'OK'
    END AS EstadoStock,
    (
        SELECT TOP 1 mi.Cantidad
        FROM Inventario.MovimientoInventario mi
        WHERE mi.ProductoID = pr.ProductoID
          AND mi.EsEntrada = 0
        ORDER BY mi.Fecha DESC
    ) AS UltimasSalidas
FROM Inventario.Producto pr
WHERE pr.Activo = 1
ORDER BY pr.StockActual ASC;

-- Verificar el cálculo de nómina de un empleado en el mes actual
SELECT
    p.Nombre + ' ' + p.Apellido AS Empleado,
    r.NombreRol AS Rol,
    es.SueldoBase,
    ec.Porcentaje AS ComisionPct,
    ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad), 0) AS TotalVentas,
    ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0), 0) AS Comision,
    es.SueldoBase +
    ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0), 0) AS TotalNomina
FROM RRHH.Empleado e
JOIN Personas.Persona p ON p.PersonaID = e.EmpleadoID
JOIN RRHH.EmpleadoRol er ON er.EmpleadoID = e.EmpleadoID
JOIN RRHH.Rol r ON r.RolID = er.RolID
JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID = e.EmpleadoID AND es.FechaFin IS NULL
JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID = e.EmpleadoID AND ec.FechaFin IS NULL
LEFT JOIN Ventas.VentaDetalleServicio vds ON vds.EmpleadoID = e.EmpleadoID
    AND EXISTS (
        SELECT 1 FROM Ventas.Venta v
        WHERE v.VentaID = vds.VentaID
          AND MONTH(v.Fecha) = MONTH(GETDATE())
          AND YEAR(v.Fecha)  = YEAR(GETDATE())
    )
WHERE e.Activo = 1 AND r.RolID IN (3,4,5,6)
GROUP BY e.EmpleadoID, p.Nombre, p.Apellido, r.NombreRol, es.SueldoBase, ec.Porcentaje
ORDER BY TotalNomina DESC;

-- Verificar que actualizar el sueldo cerró el anterior y abrió uno nuevo
SELECT
    p.Nombre + ' ' + p.Apellido AS Empleado,
    es.SueldoBase,
    CONVERT(VARCHAR(10), es.FechaInicio, 103) AS Desde,
    ISNULL(CONVERT(VARCHAR(10), es.FechaFin, 103), '→ VIGENTE') AS Hasta,
    CASE WHEN es.FechaFin IS NULL THEN 'VIGENTE' ELSE 'HISTÓRICO' END AS Estado
FROM RRHH.EmpleadoSueldo es
JOIN Personas.Persona p ON p.PersonaID = es.EmpleadoID
WHERE es.EmpleadoID = 7
ORDER BY es.FechaInicio DESC;

-- Verificar que el trigger generó la notificación tras crear la cita
SELECT
    n.NotificacionID,
    p.Nombre + ' ' + p.Apellido AS Destinatario,
    tn.Nombre AS TipoNotificacion,
    n.Mensaje,
    CONVERT(VARCHAR(16), n.Fecha, 120) AS FechaHora,
    CASE WHEN n.Leido = 1 THEN 'Leída' ELSE 'No leída' END AS Estado
FROM Notificaciones.Notificacion n
JOIN Personas.Persona p ON p.PersonaID = n.PersonaID
JOIN Notificaciones.TipoNotificacion tn ON tn.TipoNotificacionID = n.TipoNotificacionID
ORDER BY n.Fecha DESC;

-- Verificar que el trigger de stock bajo disparó la notificación al admin
SELECT
    p.Nombre + ' ' + p.Apellido AS AdminNotificado,
    n.Mensaje,
    CONVERT(VARCHAR(16), n.Fecha, 120) AS CuandoDisparó
FROM Notificaciones.Notificacion n
JOIN Personas.Persona p ON p.PersonaID = n.PersonaID
JOIN Notificaciones.TipoNotificacion tn ON tn.TipoNotificacionID = n.TipoNotificacionID
WHERE tn.Nombre = 'stock_minimo'
ORDER BY n.Fecha DESC;

-- Verificar estado de una solicitud especial y su cita creada
SELECT
    se.SolicitudID,
    p.Nombre + ' ' + p.Apellido AS Cliente,
    se.TipoSolicitud,
    CONVERT(VARCHAR(16), se.FechaSolicitada, 120) AS FechaSolicitada,
    se.Motivo,
    se.Estado,
    se.MotivoRechazo,
    se.CitaID,
    CASE
        WHEN se.CitaID IS NOT NULL
        THEN CONVERT(VARCHAR(16), c.FechaInicio, 120)
        ELSE '—'
    END AS FechaCitaCreada,
    CONVERT(VARCHAR(16), se.FechaCreacion, 120) AS FechaCreacion
FROM Agenda.SolicitudEspecial se
JOIN Personas.Persona p ON p.PersonaID = se.ClienteID
LEFT JOIN Agenda.Cita c ON c.CitaID = se.CitaID
ORDER BY se.FechaCreacion DESC;

-- Citas del día con cliente, servicio y empleado asignado
SELECT
    c.CitaID,
    p.Nombre + ' ' + p.Apellido AS Cliente,
    s.Nombre AS Servicio,
    emp.Nombre + ' ' + emp.Apellido AS Empleado,
    CONVERT(VARCHAR(5), cs.FechaInicioServicio, 108) AS HoraInicio,
    CONVERT(VARCHAR(5), cs.FechaFinServicio, 108) AS HoraFin,
    ec.Nombre AS Estado
FROM Agenda.Cita c
JOIN Personas.Persona p ON p.PersonaID = c.ClienteID
JOIN Agenda.CitaServicio cs ON cs.CitaID = c.CitaID
JOIN Servicios.Servicio s ON s.ServicioID = cs.ServicioID
JOIN Personas.Persona emp ON emp.PersonaID = cs.EmpleadoID
JOIN Agenda.EstadoCita ec ON ec.EstadoID = c.EstadoID
WHERE CAST(c.FechaInicio AS DATE) = CAST(GETDATE() AS DATE)
  AND c.EstadoID NOT IN (12, 13)
ORDER BY cs.FechaInicioServicio;

-- Ingresos totales por mes del año actual
SELECT
    MONTH(v.Fecha) AS Mes,
    COUNT(DISTINCT v.VentaID) AS TotalVentas,
    SUM(pg.Monto) AS TotalIngresos,
    AVG(pg.Monto) AS TicketPromedio
FROM Ventas.Venta v
JOIN Ventas.Pago pg ON pg.VentaID = v.VentaID
WHERE YEAR(v.Fecha) = YEAR(GETDATE())
GROUP BY MONTH(v.Fecha)
ORDER BY Mes;

-- Empleados con su sueldo y comisión vigente
SELECT
    p.Nombre + ' ' + p.Apellido AS Empleado,
    r.NombreRol AS Rol,
    es.SueldoBase,
    ec.Porcentaje AS ComisionPct,
    e.FechaContratacion
FROM RRHH.Empleado e
JOIN Personas.Persona p ON p.PersonaID = e.EmpleadoID
JOIN RRHH.EmpleadoRol er ON er.EmpleadoID = e.EmpleadoID
JOIN RRHH.Rol r ON r.RolID = er.RolID
JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID = e.EmpleadoID AND es.FechaFin IS NULL
JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID = e.EmpleadoID AND ec.FechaFin IS NULL
WHERE e.Activo = 1
ORDER BY r.RolID, p.Nombre;

-- Top 5 servicios más solicitados del mes
SELECT TOP 5
    s.Nombre AS Servicio,
    cat.Nombre AS Categoria,
    COUNT(*) AS VecesReservado,
    SUM(vds.PrecioUnitario) AS IngresosTotales
FROM Ventas.VentaDetalleServicio vds
JOIN Ventas.Venta v ON v.VentaID = vds.VentaID
JOIN Servicios.Servicio s ON s.ServicioID = vds.ServicioID
JOIN Servicios.SubcategoriaServicio sc ON sc.SubcategoriaID = s.SubcategoriaID
JOIN Servicios.CategoriaServicio cat ON cat.CategoriaID = sc.CategoriaID
WHERE MONTH(v.Fecha) = MONTH(GETDATE())
  AND YEAR(v.Fecha) = YEAR(GETDATE())
GROUP BY vds.ServicioID, s.Nombre, cat.Nombre
ORDER BY VecesReservado DESC;

-- Comisiones del mes por empleado
SELECT
    p.Nombre + ' ' + p.Apellido AS Empleado,
    r.NombreRol AS Rol,
    es.SueldoBase,
    ec.Porcentaje AS ComisionPct,
    ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad), 0) AS TotalVentas,
    ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0), 0) AS TotalComision,
    es.SueldoBase + ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0), 0) AS TotalNomina
FROM RRHH.Empleado e
JOIN Personas.Persona p ON p.PersonaID = e.EmpleadoID
JOIN RRHH.EmpleadoRol er ON er.EmpleadoID = e.EmpleadoID
JOIN RRHH.Rol r ON r.RolID = er.RolID
LEFT JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID = e.EmpleadoID AND es.FechaFin IS NULL
LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID = e.EmpleadoID AND ec.FechaFin IS NULL
LEFT JOIN Ventas.VentaDetalleServicio vds ON vds.EmpleadoID = e.EmpleadoID
    AND EXISTS (
        SELECT 1 FROM Ventas.Venta v
        WHERE v.VentaID = vds.VentaID
          AND MONTH(v.Fecha) = MONTH(GETDATE())
          AND YEAR(v.Fecha) = YEAR(GETDATE())
    )
WHERE e.Activo = 1 AND r.RolID IN (3,4,5,6)
GROUP BY e.EmpleadoID, p.Nombre, p.Apellido, r.NombreRol, es.SueldoBase, ec.Porcentaje
ORDER BY TotalNomina DESC;

-- Historial de sueldos de un empleado (cambios a lo largo del tiempo)
SELECT
    p.Nombre + ' ' + p.Apellido AS Empleado,
    es.SueldoBase,
    es.FechaInicio,
    ISNULL(CONVERT(VARCHAR, es.FechaFin, 103), 'Vigente') AS FechaFin
FROM RRHH.EmpleadoSueldo es
JOIN Personas.Persona p ON p.PersonaID = es.EmpleadoID
WHERE es.EmpleadoID = 11  -- cambiar por el ID que quieran mostrar
ORDER BY es.FechaInicio DESC;

-- Empleados con día libre aprobado esta semana
SELECT
    p.Nombre + ' ' + p.Apellido AS Empleado,
    r.NombreRol AS Rol,
    CONVERT(VARCHAR, he.Fecha, 103) AS FechaLibre,
    he.Motivo,
    he.Estado
FROM RRHH.HorarioExcepcion he
JOIN Personas.Persona p ON p.PersonaID = he.EmpleadoID
JOIN RRHH.EmpleadoRol er ON er.EmpleadoID = he.EmpleadoID
JOIN RRHH.Rol r ON r.RolID = er.RolID
WHERE he.Disponible = 0
  AND he.Estado = 'Aprobada'
  AND he.Fecha BETWEEN CAST(GETDATE() AS DATE)
      AND DATEADD(DAY, 7, CAST(GETDATE() AS DATE))
ORDER BY he.Fecha;

-- Precio vigente vs historial — demostrar FechaFin IS NULL
SELECT
    s.Nombre AS Servicio,
    sp.Precio,
    CONVERT(VARCHAR, sp.FechaInicio, 103) AS Desde,
    ISNULL(CONVERT(VARCHAR, sp.FechaFin, 103), '→ VIGENTE') AS Hasta
FROM Servicios.ServicioPrecio sp
JOIN Servicios.Servicio s ON s.ServicioID = sp.ServicioID
WHERE sp.ServicioID = 5  -- cambiar por cualquier servicio
ORDER BY sp.FechaInicio DESC;

-- Herencia de Personas.Persona (demostrar normalización)
SELECT
    p.PersonaID,
    p.Nombre + ' ' + p.Apellido AS Nombre,
    CASE
        WHEN e.EmpleadoID IS NOT NULL AND cl.ClienteID IS NOT NULL THEN 'Empleado + Cliente'
        WHEN e.EmpleadoID IS NOT NULL THEN 'Empleado'
        WHEN cl.ClienteID IS NOT NULL THEN 'Cliente'
    END AS TipoPersona,
    ISNULL(r.NombreRol, '—') AS RolLaboral,
    ISNULL(sr.Nombre, '—') AS RolSeguridad
FROM Personas.Persona p
LEFT JOIN RRHH.Empleado e ON e.EmpleadoID = p.PersonaID
LEFT JOIN Ventas.Cliente cl ON cl.ClienteID = p.PersonaID
LEFT JOIN RRHH.EmpleadoRol er ON er.EmpleadoID = e.EmpleadoID
LEFT JOIN RRHH.Rol r ON r.RolID = er.RolID
LEFT JOIN Seguridad.Usuario u ON u.PersonaID = p.PersonaID
LEFT JOIN Seguridad.UsuarioRol ur ON ur.UsuarioID = u.UsuarioID
LEFT JOIN Seguridad.Rol sr ON sr.RolID = ur.RolID
ORDER BY TipoPersona, p.Nombre;

-- SubcategoriaRol — qué rol puede hacer qué servicio
SELECT
    cat.Nombre AS Categoria,
    sc.Nombre AS Subcategoria,
    r.NombreRol AS RolRequerido
FROM Servicios.SubcategoriaRol sr
JOIN Servicios.SubcategoriaServicio sc ON sc.SubcategoriaID = sr.SubcategoriaID
JOIN Servicios.CategoriaServicio cat ON cat.CategoriaID = sc.CategoriaID
JOIN RRHH.Rol r ON r.RolID = sr.RolID
ORDER BY cat.Nombre, sc.Nombre;

-- Clientes con más visitas y total gastado
SELECT
    p.Nombre + ' ' + p.Apellido AS Cliente,
    COUNT(DISTINCT v.VentaID) AS TotalVisitas,
    SUM(pg.Monto) AS TotalGastado,
    MAX(v.Fecha) AS UltimaVisita,
    DATEDIFF(DAY, MAX(v.Fecha), GETDATE()) AS DiasDesdeUltimaVisita
FROM Ventas.Venta v
JOIN Personas.Persona p ON p.PersonaID = v.ClienteID
JOIN Ventas.Pago pg ON pg.VentaID = v.VentaID
GROUP BY v.ClienteID, p.Nombre, p.Apellido
ORDER BY TotalGastado DESC;

-- Empleados disponibles para una fecha y hora específica
SELECT
    p.Nombre + ' ' + p.Apellido AS Empleado,
    r.NombreRol AS Rol
FROM RRHH.Empleado e
JOIN Personas.Persona p ON p.PersonaID = e.EmpleadoID
JOIN RRHH.EmpleadoRol er ON er.EmpleadoID = e.EmpleadoID
JOIN RRHH.Rol r ON r.RolID = er.RolID
WHERE e.Activo = 1
  AND r.RolID IN (3,4,5,6)
  -- No tiene día libre aprobado ese día
  AND NOT EXISTS (
      SELECT 1 FROM RRHH.HorarioExcepcion he
      WHERE he.EmpleadoID = e.EmpleadoID
        AND he.Fecha = '2026-04-14'
        AND he.Disponible = 0
        AND he.Estado = 'Aprobada'
  )
  -- No tiene cita en ese horario
  AND e.EmpleadoID NOT IN (
      SELECT cs.EmpleadoID
      FROM Agenda.CitaServicio cs
      JOIN Agenda.Cita c ON c.CitaID = cs.CitaID
      WHERE c.EstadoID NOT IN (12, 13)
        AND cs.FechaInicioServicio < '2026-04-14 11:00:00'
        AND cs.FechaFinServicio    > '2026-04-14 09:00:00'
  );

-- Tasa de cancelación por mes
SELECT
    YEAR(FechaInicio) AS Anio,
    MONTH(FechaInicio) AS Mes,
    COUNT(*) AS TotalCitas,
    SUM(CASE WHEN EstadoID = 12 THEN 1 ELSE 0 END) AS Canceladas,
    SUM(CASE WHEN EstadoID = 11 THEN 1 ELSE 0 END) AS Completadas,
    CAST(
        SUM(CASE WHEN EstadoID = 12 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0)
    AS DECIMAL(5,2)) AS TasaCancelacion
FROM Agenda.Cita
GROUP BY YEAR(FechaInicio), MONTH(FechaInicio)
ORDER BY Anio DESC, Mes DESC;

-- Factura completa de una venta (servicios + productos + descuento)
SELECT
    f.NumeroFactura,
    CONVERT(VARCHAR, f.Fecha, 103) AS Fecha,
    p.Nombre + ' ' + p.Apellido AS Cliente,
    mp.Nombre AS MetodoPago,
    ISNULL(v.DescuentoPct, 0) AS DescuentoPct,
    ISNULL(v.DescuentoMonto, 0) AS DescuentoMonto,
    (
        SELECT ISNULL(SUM(PrecioUnitario * Cantidad), 0)
        FROM Ventas.VentaDetalleServicio
        WHERE VentaID = v.VentaID
    ) +
    (
        SELECT ISNULL(SUM(PrecioUnitario * Cantidad), 0)
        FROM Ventas.VentaDetalleProducto
        WHERE VentaID = v.VentaID
    ) AS SubTotal,
    pg.Monto AS TotalPagado
FROM Facturacion.Factura f
JOIN Ventas.Venta v ON v.VentaID = f.VentaID
JOIN Personas.Persona p ON p.PersonaID = v.ClienteID
JOIN Ventas.Pago pg ON pg.VentaID = v.VentaID
JOIN Ventas.MetodoPago mp ON mp.MetodoPagoID = pg.MetodoPagoID
WHERE f.FacturaID = 1;  -- cambiar por cualquier factura

-- Ver los índices creados en las tablas más críticas
SELECT
    t.name AS Tabla,
    i.name AS Indice,
    i.type_desc AS Tipo,
    STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS Columnas
FROM sys.indexes i
JOIN sys.tables t ON t.object_id = i.object_id
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE t.name IN ('Cita','CitaServicio','HorarioExcepcion','Venta','Persona')
  AND i.type > 0
GROUP BY t.name, i.name, i.type_desc
ORDER BY t.name, i.name;