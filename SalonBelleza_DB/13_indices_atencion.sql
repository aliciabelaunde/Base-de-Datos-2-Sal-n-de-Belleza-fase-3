-- COCO Salón de Belleza · SalonBelleza_DB
-- 13 · ÍNDICES

USE SalonBelleza_DB;
GO

-- MÓDULO ATENCIÓN

-- 1. Citas por fecha para agenda del día
CREATE INDEX IX_Cita_FechaEstado
ON Agenda.Cita(FechaInicio, EstadoID);

-- 2. Clientes por nombre para búsqueda rápida
CREATE INDEX IX_Persona_Nombre
ON Personas.Persona(Nombre, Apellido);

-- 3. Solicitudes especiales pendientes
CREATE INDEX IX_SolicitudEspecial_Estado
ON Agenda.SolicitudEspecial(Estado);

-- 4. Excepciones pendientes de aprobar
CREATE INDEX IX_HorarioExcepcion_Aprobado
ON RRHH.HorarioExcepcion(Aprobado, Fecha);

-- 5. Facturas por estado
CREATE INDEX IX_Factura_Estado
ON Facturacion.Factura(Estado);

-- 6. Movimientos de inventario por fecha
CREATE INDEX IX_MovimientoInventario_Fecha
ON Inventario.MovimientoInventario(Fecha);
GO