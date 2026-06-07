USE SalonBelleza_DB;
GO

-- MÓDULO CLIENTES

GRANT EXECUTE ON Ventas.SP_ObtenerPerfilCliente      TO rol_cliente;
GRANT EXECUTE ON Ventas.SP_ActualizarPerfilCliente   TO rol_cliente;

GRANT EXECUTE ON Agenda.SP_EstadisticasCliente       TO rol_cliente;
GRANT EXECUTE ON Agenda.SP_ReservarCita              TO rol_cliente;
GRANT EXECUTE ON Agenda.SP_ObtenerCitasCliente       TO rol_cliente;
GRANT EXECUTE ON Agenda.SP_CancelarCita              TO rol_cliente;
GRANT EXECUTE ON Agenda.SP_EditarCita                TO rol_cliente;

GRANT EXECUTE ON Agenda.SP_ObtenerEmpleadosDisponibles TO rol_cliente;
GRANT EXECUTE ON Agenda.SP_CrearSolicitudEspecial    TO rol_cliente;

GRANT EXECUTE ON Servicios.SP_ObtenerCatalogo        TO rol_cliente;

GRANT EXECUTE ON Ventas.SP_ObtenerComprasCliente     TO rol_cliente;
GRANT EXECUTE ON Ventas.SP_ObtenerFacturasCliente    TO rol_cliente;
GRANT EXECUTE ON Ventas.SP_ObtenerPagosCliente       TO rol_cliente;

GRANT EXECUTE ON Marketing.SP_ObtenerPromocionesActivas TO rol_cliente;

GRANT EXECUTE ON Notificaciones.SP_ObtenerNotificaciones TO rol_cliente;
GRANT EXECUTE ON Notificaciones.SP_MarcarNotificacionLeida TO rol_cliente;