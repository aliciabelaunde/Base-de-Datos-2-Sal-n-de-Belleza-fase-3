-- COCO Salón de Belleza · SalonBelleza_DB
-- 15 · TRIGGERS

USE SalonBelleza_DB;
GO

-- MÓDULO PERSONAL TÉCNICO

-- 1. Notificación al completar cita
CREATE TRIGGER Agenda.TR_NotificarCitaCompletada
ON Agenda.Cita
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

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

    -- Solo cuando cambia a Completada (4)
    -- y el estado anterior no era Completada
    INSERT INTO Notificaciones.Notificacion
        (PersonaID, TipoNotificacionID, Mensaje)
    SELECT
        i.ClienteID,
        @TipoID,
        'Tu servicio del ' +
        FORMAT(i.FechaInicio, 'dd/MM/yyyy') +
        ' fue completado. ¡Gracias por visitarnos!'
    FROM inserted i
    JOIN deleted  d ON d.CitaID = i.CitaID
    WHERE i.EstadoID = 4
      AND d.EstadoID <> 4;
END;
GO

-- 2. Notificación al aprobar excepción
CREATE TRIGGER RRHH.TR_NotificarExcepcionAprobada
ON RRHH.HorarioExcepcion
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(Aprobado) RETURN;

    -- Crear tipo de notificación si no existe
    IF NOT EXISTS (
        SELECT 1 FROM Notificaciones.TipoNotificacion
        WHERE Nombre = 'aprobacion_excepcion'
    )
        INSERT INTO Notificaciones.TipoNotificacion (Nombre)
        VALUES ('aprobacion_excepcion');

    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID
    FROM Notificaciones.TipoNotificacion
    WHERE Nombre = 'aprobacion_excepcion';

    -- Solo cuando Aprobado cambia de 0 a 1
    INSERT INTO Notificaciones.Notificacion
        (PersonaID, TipoNotificacionID, Mensaje)
    SELECT
        i.EmpleadoID,
        @TipoID,
        CASE i.Disponible
            WHEN 1 THEN 'Tu turno extra del ' +
                FORMAT(i.Fecha, 'dd/MM/yyyy') +
                ' fue aprobado.'
            ELSE 'Tu día libre del ' +
                FORMAT(i.Fecha, 'dd/MM/yyyy') +
                ' fue aprobado.'
        END
    FROM inserted i
    JOIN deleted  d ON d.ExcepcionID = i.ExcepcionID
    WHERE i.Aprobado = 1
      AND d.Aprobado = 0;
END;
GO