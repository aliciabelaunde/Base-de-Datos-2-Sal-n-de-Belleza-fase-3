-- COCO Salón de Belleza · SalonBelleza_DB
-- 13 · ÍNDICES

USE SalonBelleza_DB;
GO

-- MÓDULO PERSONAL TÉCNICO

-- 1. Citas de un empleado por fecha de inicio del servicio
CREATE INDEX IX_CitaServicio_EmpleadoFecha
ON Agenda.CitaServicio(EmpleadoID, FechaInicioServicio);

-- 2. Citas de un empleado (sin fecha)
CREATE INDEX IX_CitaServicio_EmpleadoID
ON Agenda.CitaServicio(EmpleadoID);

-- 3. Ventas generadas por un empleado
CREATE INDEX IX_Venta_EmpleadoID
ON Ventas.Venta(EmpleadoID);

-- 4. Sueldo vigente del empleado (FechaFin NULL = vigente)
CREATE INDEX IX_EmpleadoSueldo_Vigente
ON RRHH.EmpleadoSueldo(EmpleadoID, FechaFin);

-- 5. Comisión vigente del empleado
CREATE INDEX IX_EmpleadoComision_Vigente
ON RRHH.EmpleadoComision(EmpleadoID, FechaFin);

-- 6. Excepciones de horario por empleado y estado de aprobación
CREATE INDEX IX_HorarioExcepcion_Empleado
ON RRHH.HorarioExcepcion(EmpleadoID, Aprobado);

-- 7. Pago de nómina por empleado y período
CREATE INDEX IX_PagoNomina_EmpleadoPeriodo
ON RRHH.PagoNomina(EmpleadoID, Periodo);
GO