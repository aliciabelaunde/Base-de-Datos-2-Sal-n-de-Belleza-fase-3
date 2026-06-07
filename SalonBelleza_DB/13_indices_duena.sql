-- COCO Salón de Belleza · SalonBelleza_DB
-- 13 · ÍNDICES

USE SalonBelleza_DB;
GO

-- MÓDULO DUEÑA

-- 1. Ventas por año para reportes anuales
CREATE INDEX IX_Venta_Anio
ON Ventas.Venta(Fecha);

-- 2. Citas por año para estadísticas globales
CREATE INDEX IX_Cita_Anio
ON Agenda.Cita(FechaInicio);
GO