USE SalonBelleza_DB;
GO

-- MÓDULO DUEÑA

-- 1. Resumen Financiero anual
CREATE VIEW Duena.VW_ResumenFinanciero AS
SELECT
    YEAR(v.Fecha)   AS Anio,
    MONTH(v.Fecha)  AS Mes,
    ISNULL(SUM(pg.Monto), 0)  AS Ingresos,
    ISNULL((
        SELECT SUM(pn2.SueldoBase + pn2.Comision)
        FROM RRHH.PagoNomina pn2
        WHERE LEFT(pn2.Periodo, 4) = CAST(YEAR(v.Fecha) AS VARCHAR)
          AND CAST(RIGHT(pn2.Periodo, 2) AS INT) = MONTH(v.Fecha)
    ), 0)                     AS CostoNomina,
    ISNULL(SUM(pg.Monto), 0) - ISNULL((
        SELECT SUM(pn3.SueldoBase + pn3.Comision)
        FROM RRHH.PagoNomina pn3
        WHERE LEFT(pn3.Periodo, 4) = CAST(YEAR(v.Fecha) AS VARCHAR)
          AND CAST(RIGHT(pn3.Periodo, 2) AS INT) = MONTH(v.Fecha)
    ), 0)                     AS Utilidad
FROM Ventas.Venta  v
JOIN Ventas.Pago   pg ON pg.VentaID = v.VentaID
GROUP BY YEAR(v.Fecha), MONTH(v.Fecha);
GO

-- 2. Kpis del negocio
CREATE VIEW Duena.VW_KPIs AS
SELECT
    -- Ticket promedio del mes
    ISNULL(AVG(CASE WHEN MONTH(v.Fecha) = MONTH(GETDATE())
                     AND YEAR(v.Fecha)  = YEAR(GETDATE())
                THEN pg.Monto END), 0)                  AS TicketPromedio,

    -- Tasa de cancelación del mes
    CAST(
        SUM(CASE WHEN MONTH(c.FechaInicio) = MONTH(GETDATE())
                  AND YEAR(c.FechaInicio)  = YEAR(GETDATE())
                  AND c.EstadoID = 5 THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(SUM(CASE WHEN MONTH(c.FechaInicio) = MONTH(GETDATE())
                         AND YEAR(c.FechaInicio)  = YEAR(GETDATE())
                    THEN 1 ELSE 0 END), 0)
    AS DECIMAL(5,2))                                    AS TasaCancelacion,

    -- Ocupación del equipo (citas completadas / total posibles)
    COUNT(DISTINCT CASE WHEN MONTH(cs.FechaInicioServicio) = MONTH(GETDATE())
                         AND YEAR(cs.FechaInicioServicio)  = YEAR(GETDATE())
                         AND c2.EstadoID = 4
                    THEN cs.CitaServicioID END)          AS ServiciosCompletados

FROM Ventas.Venta             v
JOIN Ventas.Pago              pg ON pg.VentaID  = v.VentaID
CROSS JOIN Agenda.Cita        c
LEFT JOIN Agenda.CitaServicio cs ON cs.CitaID   = c.CitaID
LEFT JOIN Agenda.Cita         c2 ON c2.CitaID   = cs.CitaID;
GO