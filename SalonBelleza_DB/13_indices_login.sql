-- COCO Salón de Belleza · SalonBelleza_DB
-- 13 · ÍNDICES

USE SalonBelleza_DB;
GO

-- MÓDULO: LOG IN / CREAR CUENTA

-- 1. Buscar persona por email (login y registro)
CREATE INDEX IX_Persona_Email
ON Personas.Persona(Email);

-- 2. Buscar persona por teléfono (evitar duplicados en registro)
CREATE INDEX IX_Persona_Telefono
ON Personas.Persona(Telefono);

-- 3. Buscar usuario por username al iniciar sesión
CREATE INDEX IX_Usuario_Username
ON Seguridad.Usuario(Username);

-- 4. Buscar usuario por PersonaID
CREATE INDEX IX_Usuario_PersonaID
ON Seguridad.Usuario(PersonaID);

-- 5. Buscar roles de un usuario
CREATE INDEX IX_UsuarioRol_UsuarioID
ON Seguridad.UsuarioRol(UsuarioID);
GO