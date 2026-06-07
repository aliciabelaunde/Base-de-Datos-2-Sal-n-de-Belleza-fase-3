USE SalonBelleza_DB;
GO

-- MÓDULO DUEÑA

GRANT EXECUTE ON Duena.SP_ResumenEjecutivo           TO rol_duena;
GRANT EXECUTE ON Duena.SP_ReporteAnual               TO rol_duena;
GRANT EXECUTE ON Duena.SP_VerTodosLosSueldos         TO rol_duena;

GRANT EXECUTE ON Admin.SP_ReporteVentas              TO rol_duena;

GRANT EXECUTE ON Inventario.SP_ObtenerInventario     TO rol_duena;
GRANT EXECUTE ON Marketing.SP_ListarPromociones      TO rol_duena;
GRANT EXECUTE ON Servicios.SP_ListarServicios        TO rol_duena;
GRANT EXECUTE ON RRHH.SP_ListarEmpleados             TO rol_duena;

GRANT EXECUTE ON Notificaciones.SP_ObtenerNotificaciones TO rol_duena;
GRANT EXECUTE ON Notificaciones.SP_MarcarNotificacionLeida TO rol_duena;
