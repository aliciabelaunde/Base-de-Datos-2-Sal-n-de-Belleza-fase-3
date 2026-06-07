USE SalonBelleza_DB;
GO

-- MÓDULO ATENCIÓN

GRANT EXECUTE ON Agenda.SP_PanelRecepcion            TO rol_recepcion;

-- Citas
GRANT EXECUTE ON Agenda.SP_GestionCitas              TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_ConfirmarCita             TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_CrearCitaRecepcion        TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_EditarCitaRecepcion       TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_CancelarCitaRecepcion     TO rol_recepcion;

-- Clientes
GRANT EXECUTE ON Ventas.SP_ObtenerClientes           TO rol_recepcion;
GRANT EXECUTE ON Ventas.SP_DetalleCliente            TO rol_recepcion;
GRANT EXECUTE ON Ventas.SP_RegistrarClienteRecepcion TO rol_recepcion;

-- Facturación
GRANT EXECUTE ON Facturacion.SP_ObtenerFacturas      TO rol_recepcion;
GRANT EXECUTE ON Facturacion.SP_MarcarFacturaPagada  TO rol_recepcion;
GRANT EXECUTE ON Facturacion.SP_AnularFactura        TO rol_recepcion;
GRANT EXECUTE ON Facturacion.SP_DetalleFactura       TO rol_recepcion;

-- Agenda avanzada
GRANT EXECUTE ON Agenda.SP_AprobarSolicitudEspecial  TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_ObtenerSolicitudesEspeciales TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_ResolverSolicitudEspecial TO rol_recepcion;

-- Notificaciones
GRANT EXECUTE ON Notificaciones.SP_ObtenerNotificacionesRecepcion TO rol_recepcion;
GRANT EXECUTE ON Notificaciones.SP_MarcarNotificacionLeida        TO rol_recepcion;

-- Catálogo
GRANT EXECUTE ON Servicios.SP_ObtenerCatalogo        TO rol_recepcion;