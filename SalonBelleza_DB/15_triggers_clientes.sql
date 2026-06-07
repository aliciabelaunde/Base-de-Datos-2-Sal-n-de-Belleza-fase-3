-- COCO Salón de Belleza · SalonBelleza_DB
-- 15 · TRIGGERS

USE SalonBelleza_DB;
GO

--  MÓDULO CLIENTES

-- 1. Notificar al reservar cita
CREATE TRIGGER Agenda.TR_NotificarNuevaCita
ON Agenda.Cita
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Crear tipo de notificación si no existe
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

    -- Insertar notificación para el cliente
    INSERT INTO Notificaciones.Notificacion
        (PersonaID, TipoNotificacionID, Mensaje)
    SELECT
        i.ClienteID,
        @TipoID,
        '¡Tu cita fue reservada para el ' +
        FORMAT(i.FechaInicio, 'dd/MM/yyyy') +
        ' a las ' +
        FORMAT(i.FechaInicio, 'HH:mm') +
        'h. ¡Te esperamos!'
    FROM inserted i;
END;
GO

-- 2. Notificación al cancelar cita
CREATE TRIGGER Agenda.TR_NotificarCancelacionCita
ON Agenda.Cita
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Solo actuar cuando cambia el EstadoID
    IF NOT UPDATE(EstadoID) RETURN;

    -- Crear tipo de notificación si no existe
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

    -- Solo cuando el nuevo estado es Cancelada (5)
    -- y el estado anterior no era Cancelada
    INSERT INTO Notificaciones.Notificacion
        (PersonaID, TipoNotificacionID, Mensaje)
    SELECT
        i.ClienteID,
        @TipoID,
        'Tu cita del ' +
        FORMAT(i.FechaInicio, 'dd/MM/yyyy') +
        ' a las ' +
        FORMAT(i.FechaInicio, 'HH:mm') +
        'h ha sido cancelada.'
    FROM inserted i
    JOIN deleted  d ON d.CitaID = i.CitaID
    WHERE i.EstadoID = 5
      AND d.EstadoID <> 5;
END;
GO

-- 3. Notificación al editar cita
CREATE TRIGGER Agenda.TR_NotificarEdicionCita
ON Agenda.Cita
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Solo actuar cuando cambia FechaInicio
    IF NOT UPDATE(FechaInicio) RETURN;

    -- Crear tipo de notificación si no existe
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

    -- Solo cuando la fecha realmente cambió
    INSERT INTO Notificaciones.Notificacion
        (PersonaID, TipoNotificacionID, Mensaje)
    SELECT
        i.ClienteID,
        @TipoID,
        'Tu cita fue reprogramada para el ' +
        FORMAT(i.FechaInicio, 'dd/MM/yyyy') +
        ' a las ' +
        FORMAT(i.FechaInicio, 'HH:mm') + 'h.'
    FROM inserted i
    JOIN deleted  d ON d.CitaID = i.CitaID
    WHERE i.FechaInicio <> d.FechaInicio
      AND i.EstadoID    NOT IN (5, 6);
END;
GO