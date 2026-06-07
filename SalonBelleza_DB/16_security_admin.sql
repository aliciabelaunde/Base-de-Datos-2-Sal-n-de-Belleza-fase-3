USE SalonBelleza_DB;
GO

-- MÓDULO ADMINISTRADOR

GRANT EXECUTE ON Admin.SP_ResumenGeneral             TO rol_admin;
GRANT EXECUTE ON Admin.SP_ReporteVentas              TO rol_admin;
GRANT EXECUTE ON Admin.SP_ObtenerPerfil              TO rol_admin;
GRANT EXECUTE ON Admin.SP_ActualizarPerfil           TO rol_admin;

-- RRHH
GRANT EXECUTE ON RRHH.SP_ListarEmpleados             TO rol_admin;
GRANT EXECUTE ON RRHH.SP_ActualizarSueldo            TO rol_admin;
GRANT EXECUTE ON RRHH.SP_ActualizarComision          TO rol_admin;
GRANT EXECUTE ON RRHH.SP_RegistrarEmpleado           TO rol_admin;
GRANT EXECUTE ON RRHH.SP_NominaDelMes                TO rol_admin;
GRANT EXECUTE ON RRHH.SP_RegistrarPagoNomina         TO rol_admin;
GRANT EXECUTE ON RRHH.SP_ListarEmpleadosSinAdmin     TO rol_admin;
GRANT EXECUTE ON RRHH.SP_ListarRolesPersonal         TO rol_admin;
GRANT EXECUTE ON RRHH.SP_SincronizarRolesSeguridad   TO rol_admin;

-- Inventario
GRANT EXECUTE ON Inventario.SP_ObtenerInventario     TO rol_admin;
GRANT EXECUTE ON Inventario.SP_AjustarStock          TO rol_admin;

-- Servicios
GRANT EXECUTE ON Servicios.SP_ListarServicios        TO rol_admin;
GRANT EXECUTE ON Servicios.SP_ActualizarPrecio       TO rol_admin;

-- Marketing
GRANT EXECUTE ON Marketing.SP_ListarPromociones      TO rol_admin;
GRANT EXECUTE ON Marketing.SP_CrearPromocion         TO rol_admin;

-- Tablas necesarias
GRANT SELECT, INSERT ON RRHH.PagoNomina              TO rol_admin;
GRANT SELECT ON RRHH.EmpleadoSueldo                  TO rol_admin;
GRANT SELECT ON RRHH.EmpleadoComision                TO rol_admin;