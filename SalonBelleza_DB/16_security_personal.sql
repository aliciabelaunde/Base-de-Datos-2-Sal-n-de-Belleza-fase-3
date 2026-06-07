USE SalonBelleza_DB;
GO

-- MÓDULO PERSONAL TÉCNICO

GRANT EXECUTE ON Agenda.SP_AgendaDelDia              TO rol_tecnico;
GRANT EXECUTE ON Agenda.SP_CompletarCita             TO rol_tecnico;

GRANT EXECUTE ON RRHH.SP_ObtenerHorarioEmpleado      TO rol_tecnico;
GRANT EXECUTE ON RRHH.SP_SolicitarExcepcion          TO rol_tecnico;

GRANT EXECUTE ON Ventas.SP_ObtenerClientesEmpleado   TO rol_tecnico;
GRANT EXECUTE ON Ventas.SP_ObtenerFichaCliente       TO rol_tecnico;
GRANT EXECUTE ON Ventas.SP_ActualizarNotasTecnicas   TO rol_tecnico;
GRANT EXECUTE ON Ventas.SP_ObtenerVentasEmpleado     TO rol_tecnico;

GRANT EXECUTE ON RRHH.SP_ObtenerSueldoComisiones     TO rol_tecnico;
GRANT EXECUTE ON RRHH.SP_ObtenerPerfilEmpleado       TO rol_tecnico;
GRANT EXECUTE ON RRHH.SP_ActualizarPerfilEmpleado    TO rol_tecnico;