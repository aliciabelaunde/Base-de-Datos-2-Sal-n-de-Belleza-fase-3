USE SalonBelleza_DB;
GO

-- MÓDULO ADMINISTRADOR

-- 1. Productos con stock bajo
CREATE VIEW Inventario.VW_StockBajo AS
SELECT
    p.ProductoID,
    p.Nombre,
    p.StockActual,
    p.StockMinimo,
    p.StockActual - p.StockMinimo AS Diferencia,
    ISNULL(pp.Precio, 0)          AS Precio,
    pv.Nombre                     AS Proveedor
FROM Inventario.Producto          p
LEFT JOIN Inventario.ProductoPrecio    pp  ON pp.ProductoID = p.ProductoID
                                          AND pp.FechaFin  IS NULL
LEFT JOIN Inventario.ProductoProveedor ppv ON ppv.ProductoID = p.ProductoID
LEFT JOIN Inventario.Proveedor         pv  ON pv.ProveedorID = ppv.ProveedorID
WHERE p.StockActual <= p.StockMinimo
  AND p.Activo      = 1;
GO

-- 2. Resumen de ventas por mes
CREATE VIEW Admin.VW_VentasPorMes AS
SELECT
    YEAR(v.Fecha)   AS Anio,
    MONTH(v.Fecha)  AS Mes,
    COUNT(DISTINCT v.VentaID)   AS TotalVentas,
    ISNULL(SUM(pg.Monto), 0)    AS TotalIngresos,
    ISNULL(AVG(pg.Monto), 0)    AS TicketPromedio
FROM Ventas.Venta  v
JOIN Ventas.Pago   pg ON pg.VentaID = v.VentaID
GROUP BY YEAR(v.Fecha), MONTH(v.Fecha);
GO

-- 3. Nómina vigente
CREATE VIEW Admin.VW_NominaVigente AS
SELECT
    e.EmpleadoID,
    p.Nombre,
    p.Apellido,
    r.NombreRol,
    ISNULL(es.SueldoBase, 0)    AS SueldoBase,
    ISNULL(ec.Porcentaje, 0)    AS PorcentajeComision,
    e.FechaContratacion,
    e.Activo
FROM RRHH.Empleado            e
JOIN Personas.Persona          p  ON p.PersonaID  = e.EmpleadoID
JOIN RRHH.EmpleadoRol          er ON er.EmpleadoID = e.EmpleadoID
JOIN RRHH.Rol                  r  ON r.RolID       = er.RolID
LEFT JOIN RRHH.EmpleadoSueldo  es ON es.EmpleadoID = e.EmpleadoID
                                 AND es.FechaFin  IS NULL
LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID = e.EmpleadoID
                                  AND ec.FechaFin  IS NULL
WHERE e.Activo = 1
  AND r.RolID IN (3, 4, 5, 6);
GO