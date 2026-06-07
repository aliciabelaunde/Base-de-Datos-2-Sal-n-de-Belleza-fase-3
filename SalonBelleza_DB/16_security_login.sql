USE SalonBelleza_DB;
GO

-- MÓDULO: LOG IN / CREAR CUENTA

-- ROLES
CREATE ROLE rol_admin;
CREATE ROLE rol_recepcion;
CREATE ROLE rol_cliente;
CREATE ROLE rol_tecnico;
CREATE ROLE rol_duena;
CREATE ROLE rol_auth;
GO

-- AUTH (LOGIN / REGISTRO)

GRANT EXECUTE ON Seguridad.SP_RegistrarCliente       TO rol_auth;
GRANT EXECUTE ON Seguridad.SP_Login                  TO rol_auth;

GRANT SELECT ON Seguridad.Rol                        TO rol_auth;
GRANT SELECT ON Seguridad.UsuarioRol                 TO rol_auth;

GO