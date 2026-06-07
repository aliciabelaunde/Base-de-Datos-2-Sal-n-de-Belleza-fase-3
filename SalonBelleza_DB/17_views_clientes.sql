USE SalonBelleza_DB;
GO

-- MÓDULO CLIENTES

-- 1. Servicios con precio vigente
CREATE VIEW Servicios.VW_ServiciosConPrecio AS
SELECT
    s.ServicioID,
    s.Nombre,
    s.Descripcion,
    s.DuracionMin,
    s.Activo,
    sc.SubcategoriaID,
    sc.Nombre       AS Subcategoria,
    c.CategoriaID,
    c.Nombre        AS Categoria,
    sp.Precio
FROM Servicios.Servicio             s
JOIN Servicios.SubcategoriaServicio sc ON sc.SubcategoriaID = s.SubcategoriaID
JOIN Servicios.CategoriaServicio    c  ON c.CategoriaID     = sc.CategoriaID
JOIN Servicios.ServicioPrecio       sp ON sp.ServicioID     = s.ServicioID
WHERE s.Activo     = 1
  AND sp.FechaFin IS NULL;
GO

-- 2. Citas completas del cliente
CREATE VIEW Agenda.VW_CitasCompletas AS
SELECT
    c.CitaID,
    c.ClienteID,
    c.FechaInicio,
    cs.CitaServicioID,
    cs.ServicioID,
    s.Nombre            AS Servicio,
    s.DuracionMin,
    cs.Orden,
    cs.EsParalelo,
    cs.FechaInicioServicio,
    cs.FechaFinServicio,
    cs.EmpleadoID,
    e.Nombre            AS NombreEmpleado,
    e.Apellido          AS ApellidoEmpleado,
    ec.EstadoID,
    ec.Nombre           AS Estado,
    sp.Precio
FROM Agenda.Cita              c
JOIN Agenda.CitaServicio      cs ON cs.CitaID      = c.CitaID
JOIN Servicios.Servicio       s  ON s.ServicioID   = cs.ServicioID
JOIN Personas.Persona         e  ON e.PersonaID    = cs.EmpleadoID
JOIN Agenda.EstadoCita        ec ON ec.EstadoID    = c.EstadoID
JOIN Servicios.ServicioPrecio sp ON sp.ServicioID  = s.ServicioID
                                AND sp.FechaFin   IS NULL;
GO

-- 3. Promociones activas
CREATE VIEW Marketing.VW_PromocionesActivas AS
SELECT
    pr.PromocionID,
    pr.Nombre,
    pr.Descripcion,
    pr.Descuento,
    pr.FechaInicio,
    pr.FechaFin,
    s.ServicioID,
    s.Nombre        AS ServicioAplicable,
    sp.Precio       AS PrecioOriginal,
    sp.Precio * (1 - pr.Descuento / 100.0) AS PrecioConDescuento
FROM Marketing.Promocion         pr
JOIN Marketing.PromocionServicio ps ON ps.PromocionID = pr.PromocionID
JOIN Servicios.Servicio          s  ON s.ServicioID   = ps.ServicioID
JOIN Servicios.ServicioPrecio    sp ON sp.ServicioID  = s.ServicioID
                                   AND sp.FechaFin   IS NULL
WHERE pr.Activo      = 1
  AND pr.FechaInicio <= CAST(GETDATE() AS DATE)
  AND pr.FechaFin   >= CAST(GETDATE() AS DATE);
GO

-- 4. Perfil completo del cliente
CREATE VIEW Ventas.VW_PerfilCliente AS
SELECT
    p.PersonaID,
    p.Nombre,
    p.Apellido,
    p.Email,
    p.Telefono,
    p.FechaNacimiento,
    p.FechaRegistro,
    p.Activo,
    cd.Alergias,
    cd.Contraindicaciones,
    cd.NotasTecnicas
FROM Personas.Persona           p
JOIN Ventas.Cliente              c  ON c.ClienteID   = p.PersonaID
LEFT JOIN Ventas.ClienteDetalle  cd ON cd.ClienteID  = c.ClienteID;
GO

-- 5. Compras completas del cliente
CREATE VIEW Ventas.VW_ComprasCliente AS
SELECT
    v.VentaID,
    v.ClienteID,
    v.Fecha,
    v.Estado            AS EstadoVenta,
    s.Nombre            AS Item,
    'Servicio'          AS Tipo,
    vds.Cantidad,
    vds.PrecioUnitario,
    vds.PrecioUnitario * vds.Cantidad AS Total,
    f.NumeroFactura,
    f.Estado            AS EstadoFactura
FROM Ventas.Venta                v
JOIN Ventas.VentaDetalleServicio vds ON vds.VentaID   = v.VentaID
JOIN Servicios.Servicio          s   ON s.ServicioID  = vds.ServicioID
LEFT JOIN Facturacion.Factura    f   ON f.VentaID     = v.VentaID

UNION ALL

SELECT
    v.VentaID,
    v.ClienteID,
    v.Fecha,
    v.Estado            AS EstadoVenta,
    p.Nombre            AS Item,
    'Producto'          AS Tipo,
    vdp.Cantidad,
    vdp.PrecioUnitario,
    vdp.PrecioUnitario * vdp.Cantidad AS Total,
    f.NumeroFactura,
    f.Estado            AS EstadoFactura
FROM Ventas.Venta                v
JOIN Ventas.VentaDetalleProducto vdp ON vdp.VentaID   = v.VentaID
JOIN Inventario.Producto         p   ON p.ProductoID  = vdp.ProductoID
LEFT JOIN Facturacion.Factura    f   ON f.VentaID     = v.VentaID;
GO

-- 6. Notificaciones no leidas
CREATE VIEW Notificaciones.VW_NoLeidas AS
SELECT
    n.NotificacionID,
    n.PersonaID,
    n.Mensaje,
    n.Fecha,
    tn.Nombre           AS TipoNotificacion
FROM Notificaciones.Notificacion     n
JOIN Notificaciones.TipoNotificacion tn
    ON tn.TipoNotificacionID = n.TipoNotificacionID
WHERE n.Leido = 0;
GO

-- 7. Empleados activos con rol técnico
CREATE VIEW RRHH.VW_EmpleadosActivos AS
SELECT
    e.EmpleadoID,
    p.Nombre,
    p.Apellido,
    r.RolID,
    r.NombreRol,
    e.FechaContratacion
FROM RRHH.Empleado    e
JOIN Personas.Persona  p  ON p.PersonaID   = e.EmpleadoID
JOIN RRHH.EmpleadoRol  er ON er.EmpleadoID = e.EmpleadoID
JOIN RRHH.Rol          r  ON r.RolID       = er.RolID
WHERE e.Activo  = 1
  AND r.RolID  IN (3, 4, 5, 6);
-- RolID 3 = Estilista
-- RolID 4 = Colorista
-- RolID 5 = Manicurista / Pedicurista
-- RolID 6 = Maquillador/a
GO