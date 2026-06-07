-- COCO Salón de Belleza · SalonBelleza_DB
-- 14 · STORED PROCEDURES · MÓDULO LOGIN / REGISTRO

USE SalonBelleza_DB;
GO

-- 1. Registrar Cliente
CREATE PROCEDURE Seguridad.SP_RegistrarCliente
    @Nombre   VARCHAR(100),
    @Apellido VARCHAR(100),
    @Telefono VARCHAR(20),
    @Email    VARCHAR(100),
    @PassHash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email = @Email)
    BEGIN RAISERROR('Este correo ya está registrado', 16, 1); RETURN; END

    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Telefono = @Telefono)
    BEGIN RAISERROR('Este teléfono ya está registrado', 16, 1); RETURN; END

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @PersonaID INT;
        INSERT INTO Personas.Persona (Nombre, Apellido, Telefono, Email)
        VALUES (@Nombre, @Apellido, @Telefono, @Email);
        SET @PersonaID = SCOPE_IDENTITY();

        INSERT INTO Ventas.Cliente (ClienteID) VALUES (@PersonaID);

        DECLARE @UsuarioID INT;
        INSERT INTO Seguridad.Usuario (PersonaID, Username, PasswordHash)
        VALUES (@PersonaID, @Email, @PassHash);
        SET @UsuarioID = SCOPE_IDENTITY();

        -- RolID 3 = Cliente
        INSERT INTO Seguridad.UsuarioRol (UsuarioID, RolID) VALUES (@UsuarioID, 3);

        COMMIT;
        SELECT @PersonaID AS PersonaID, 'Cuenta creada exitosamente' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR('Error al crear la cuenta', 16, 1);
    END CATCH
END;
GO

-- 2. Login
--    Devuelve datos del usuario para que el backend genere el JWT
CREATE PROCEDURE Seguridad.SP_Login
    @Email VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.UsuarioID,
        u.PasswordHash,
        p.Nombre,
        p.Apellido,
        p.PersonaID,
        r.RolID,
        r.Nombre AS Rol
    FROM Seguridad.Usuario    u
    JOIN Personas.Persona     p  ON p.PersonaID  = u.PersonaID
    JOIN Seguridad.UsuarioRol ur ON ur.UsuarioID = u.UsuarioID
    JOIN Seguridad.Rol        r  ON r.RolID      = ur.RolID
    WHERE u.Username = @Email
      AND u.Activo   = 1;
END;
GO