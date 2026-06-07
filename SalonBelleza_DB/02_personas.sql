-- COCO Salón de Belleza · SalonBelleza_DB
-- 02 · TABLAS · MÓDULO PERSONAS

USE SalonBelleza_DB;
GO

-- 1. Persona
--    Tabla base para clientes, empleados y usuarios del sistema
CREATE TABLE Personas.Persona (
    PersonaID       INT          IDENTITY PRIMARY KEY,
    Nombre          VARCHAR(100) NOT NULL,
    Apellido        VARCHAR(100) NOT NULL,
    Telefono        VARCHAR(20)  NOT NULL UNIQUE,
    Email           VARCHAR(100) UNIQUE,
    FechaNacimiento DATE,
    Activo          BIT          NOT NULL DEFAULT 1,
    FechaRegistro   DATETIME     NOT NULL DEFAULT GETDATE()
);