-- COCO Salón de Belleza · SalonBelleza_DB
-- 13 · ÍNDICES

USE SalonBelleza_DB;
GO

-- MÓDULO: CLIENTES

-- 1. Acelera la búsqueda de todas las citas de un cliente
CREATE INDEX IX_Cita_ClienteID
ON Agenda.Cita(ClienteID);

-- 2. Acelera el ordenamiento y filtrado de citas por fecha
CREATE INDEX IX_Cita_FechaInicio
ON Agenda.Cita(FechaInicio);

-- 3. Acelera el filtrado de citas por estado
CREATE INDEX IX_Cita_EstadoID
ON Agenda.Cita(EstadoID);

-- 4. Acelera la búsqueda del empleado asignado a una cita
CREATE INDEX IX_CitaEmpleado_CitaID
ON Agenda.CitaEmpleado(CitaID);

-- 5. Acelera la búsqueda de servicios de una cita
CREATE INDEX IX_CitaServicio_CitaID
ON Agenda.CitaServicio(CitaID);

-- 6. Acelera la búsqueda de citas asignadas a un empleado
CREATE INDEX IX_CitaServicio_EmpleadoID
ON Agenda.CitaServicio(EmpleadoID);

-- 7. Acelera la búsqueda de servicios por horario de inicio
CREATE INDEX IX_CitaServicio_FechaInicio
ON Agenda.CitaServicio(FechaInicioServicio);

-- 8. Acelera la búsqueda de todas las ventas de un cliente
CREATE INDEX IX_Venta_ClienteID
ON Ventas.Venta(ClienteID);

-- 9. Acelera el ordenamiento de ventas por fecha
CREATE INDEX IX_Venta_Fecha
ON Ventas.Venta(Fecha);

-- 10. Acelera la búsqueda de servicios dentro de una venta
CREATE INDEX IX_VentaDetalleServicio_VentaID
ON Ventas.VentaDetalleServicio(VentaID);

-- 11. Acelera la búsqueda de productos dentro de una venta
CREATE INDEX IX_VentaDetalleProducto_VentaID
ON Ventas.VentaDetalleProducto(VentaID);

-- 12. Acelera la búsqueda de pagos asociados a una venta
CREATE INDEX IX_Pago_VentaID
ON Ventas.Pago(VentaID);

-- 13. Acelera la búsqueda de la factura de una venta
CREATE INDEX IX_Factura_VentaID
ON Facturacion.Factura(VentaID);

-- 14. Acelera el filtrado de servicios activos
CREATE INDEX IX_Servicio_Activo
ON Servicios.Servicio(Activo);

-- 15. Acelera la búsqueda de servicios por subcategoría
CREATE INDEX IX_Servicio_SubcategoriaID
ON Servicios.Servicio(SubcategoriaID);

-- 16. Acelera la búsqueda del precio vigente de un servicio
CREATE INDEX IX_ServicioPrecio_Vigente
ON Servicios.ServicioPrecio(ServicioID, FechaFin);

-- 17. Acelera la búsqueda de promociones activas por fecha
CREATE INDEX IX_Promocion_Fechas
ON Marketing.Promocion(FechaInicio, FechaFin, Activo);

-- 18. Acelera la búsqueda de servicios que aplican
CREATE INDEX IX_PromocionServicio_PromocionID
ON Marketing.PromocionServicio(PromocionID);

-- 19. Acelera la búsqueda de notificaciones de una persona
CREATE INDEX IX_Notificacion_PersonaID
ON Notificaciones.Notificacion(PersonaID, Leido);

-- 20. Acelera la búsqueda de empleados por rol
CREATE INDEX IX_EmpleadoRol_RolID
ON RRHH.EmpleadoRol(RolID);

-- 21. Acelera la búsqueda del horario de un empleado
CREATE INDEX IX_HorarioEmpleado_EmpleadoID
ON RRHH.HorarioEmpleado(EmpleadoID, DiaSemana);

-- 22. Acelera la búsqueda de excepciones de horario
CREATE INDEX IX_HorarioExcepcion_EmpleadoFecha
ON RRHH.HorarioExcepcion(EmpleadoID, Fecha);

-- 23. Acelera la búsqueda de solicitudes especiales
CREATE INDEX IX_SolicitudEspecial_ClienteID
ON Agenda.SolicitudEspecial(ClienteID);
GO