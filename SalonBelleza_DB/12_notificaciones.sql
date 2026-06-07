-- COCO Salón de Belleza · SalonBelleza_DB
-- 12 · TABLAS · MÓDULO NOTIFICACIONES

USE SalonBelleza_DB;
GO

-- 1. TipoNotificacion
--    Valores: recordatorio_cita · nuevo_cliente · stock_minimo
--             actualizacion_sueldo · aprobacion_excepcion
--             solicitud_aprobada (8) · solicitud_rechazada (9)
CREATE TABLE Notificaciones.TipoNotificacion (
    TipoNotificacionID INT         IDENTITY PRIMARY KEY,
    Nombre             VARCHAR(50) NOT NULL UNIQUE
);

-- 2. Notificacion
CREATE TABLE Notificaciones.Notificacion (
    NotificacionID     INT          IDENTITY PRIMARY KEY,
    PersonaID          INT          NOT NULL,
    TipoNotificacionID INT          NOT NULL,
    Mensaje            VARCHAR(500) NOT NULL,
    Fecha              DATETIME     NOT NULL DEFAULT GETDATE(),
    Leido              BIT          NOT NULL DEFAULT 0,
    FOREIGN KEY (PersonaID)          REFERENCES Personas.Persona(PersonaID),
    FOREIGN KEY (TipoNotificacionID) REFERENCES Notificaciones.TipoNotificacion(TipoNotificacionID)
);