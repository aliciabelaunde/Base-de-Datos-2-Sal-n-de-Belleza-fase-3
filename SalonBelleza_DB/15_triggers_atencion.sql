-- COCO Salón de Belleza · SalonBelleza_DB
-- 15 · TRIGGERS

USE SalonBelleza_DB;
GO

-- MÓDULO ATENCIÓN

-- 1. Notificación al confirmar cita
CREATE TRIGGER Agenda.TR_NotificarCitaConfirmada
ON Agenda.Cita
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(EstadoID) RETURN;

    IF NOT EXISTS (
        SELECT 1 FROM Notificaciones.TipoNotificacion
        WHERE Nombre = 'recordatorio_cita'
    )
        INSERT INTO Notificaciones.TipoNotificacion (Nombre)
        VALUES ('recordatorio_cita');

    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID
    FROM Notificaciones.TipoNotificacion
    WHERE Nombre = 'recordatorio_cita';

    -- Solo cuando cambia de Programada(1) a Confirmada(2)
    INSERT INTO Notificaciones.Notificacion
        (PersonaID, TipoNotificacionID, Mensaje)
    SELECT
        i.ClienteID,
        @TipoID,
        'Tu cita del ' +
        FORMAT(i.FechaInicio, 'dd/MM/yyyy') +
        ' a las ' +
        FORMAT(i.FechaInicio, 'HH:mm') +
        'h fue confirmada. ¡Te esperamos!'
    FROM inserted i
    JOIN deleted  d ON d.CitaID = i.CitaID
    WHERE i.EstadoID = 2
      AND d.EstadoID = 1;
END;
GO

-- 2. Notificación al registrar nuevo cliente
CREATE TRIGGER Ventas.TR_NotificarNuevoCliente
ON Ventas.Cliente
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM Notificaciones.TipoNotificacion
        WHERE Nombre = 'nuevo_cliente'
    )
        INSERT INTO Notificaciones.TipoNotificacion (Nombre)
        VALUES ('nuevo_cliente');

    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID
    FROM Notificaciones.TipoNotificacion
    WHERE Nombre = 'nuevo_cliente';

    -- Notificar a todos los usuarios de Atención y soporte (RolID=4)
    INSERT INTO Notificaciones.Notificacion
        (PersonaID, TipoNotificacionID, Mensaje)
    SELECT
        u.PersonaID,
        @TipoID,
        'Nueva clienta registrada: ' +
        p.Nombre + ' ' + p.Apellido +
        ' · ' + p.Telefono
    FROM inserted           i
    JOIN Personas.Persona   p  ON p.PersonaID  = i.ClienteID
    CROSS JOIN Seguridad.Usuario    u
    JOIN Seguridad.UsuarioRol       ur ON ur.UsuarioID = u.UsuarioID
    WHERE ur.RolID  = 4
      AND u.Activo  = 1;
END;
GO