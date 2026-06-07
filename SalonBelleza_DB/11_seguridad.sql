-- COCO Salón de Belleza · SalonBelleza_DB
-- 11 · TABLAS · MÓDULO SEGURIDAD

USE SalonBelleza_DB;
GO

-- 1. Usuario
CREATE TABLE Seguridad.Usuario (
    UsuarioID     INT          IDENTITY PRIMARY KEY,
    PersonaID     INT          NOT NULL UNIQUE,
    Username      VARCHAR(50)  NOT NULL UNIQUE,
    PasswordHash  VARCHAR(255) NOT NULL,
    Activo        BIT          NOT NULL DEFAULT 1,
    FechaCreacion DATETIME     NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (PersonaID) REFERENCES Personas.Persona(PersonaID)
);

-- 2. Rol de seguridad
--    RolID 1=Dueño/a  2=Administrador  3=Cliente
--    RolID 4=Atención y soporte  5=Personal técnico
CREATE TABLE Seguridad.Rol (
    RolID  INT         IDENTITY PRIMARY KEY,
    Nombre VARCHAR(50) NOT NULL UNIQUE
);

-- 3. UsuarioRol
--    Un usuario puede tener múltiples roles (ej. Colorista + Recepcionista)
CREATE TABLE Seguridad.UsuarioRol (
    UsuarioID INT NOT NULL,
    RolID     INT NOT NULL,
    PRIMARY KEY (UsuarioID, RolID),
    FOREIGN KEY (UsuarioID) REFERENCES Seguridad.Usuario(UsuarioID),
    FOREIGN KEY (RolID)     REFERENCES Seguridad.Rol(RolID)
);