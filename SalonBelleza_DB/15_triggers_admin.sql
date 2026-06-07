-- COCO Salón de Belleza · SalonBelleza_DB
-- 15 · TRIGGERS

USE SalonBelleza_DB;
GO

-- MÓDULO ADMINISTRADOR

-- 1. Alerta de stock bajo
DROP TRIGGER IF EXISTS Inventario.TR_AlertaStockBajo;
GO

CREATE TRIGGER Inventario.TR_AlertaStockBajo
ON Inventario.Producto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(StockActual) RETURN;

    IF NOT EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted  d ON d.ProductoID = i.ProductoID
        WHERE i.StockActual <= i.StockMinimo
          AND d.StockActual  > d.StockMinimo
          AND i.Activo       = 1
    ) RETURN;

    IF NOT EXISTS (
        SELECT 1 FROM Notificaciones.TipoNotificacion
        WHERE Nombre = 'stock_minimo'
    )
        INSERT INTO Notificaciones.TipoNotificacion (Nombre)
        VALUES ('stock_minimo');

    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID
    FROM Notificaciones.TipoNotificacion
    WHERE Nombre = 'stock_minimo';

    -- Solo notifica a Administradores (RolID 2)
    INSERT INTO Notificaciones.Notificacion
        (PersonaID, TipoNotificacionID, Mensaje)
    SELECT
        u.PersonaID,
        @TipoID,
        'Stock bajo: ' + i.Nombre +
        ' · Stock actual: ' + CAST(i.StockActual AS VARCHAR) +
        ' · Mínimo: '       + CAST(i.StockMinimo AS VARCHAR)
    FROM inserted           i
    JOIN deleted            d  ON d.ProductoID = i.ProductoID
    CROSS JOIN Seguridad.Usuario    u
    JOIN Seguridad.UsuarioRol       ur ON ur.UsuarioID = u.UsuarioID
    WHERE ur.RolID       = 2
      AND u.Activo       = 1
      AND i.StockActual <= i.StockMinimo
      AND d.StockActual  > d.StockMinimo
      AND i.Activo       = 1;
END;
GO

-- 2. Notificación al actualizar sueldo
CREATE TRIGGER RRHH.TR_NotificarActualizacionSueldo
ON RRHH.EmpleadoSueldo
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM Notificaciones.TipoNotificacion
        WHERE Nombre = 'actualizacion_sueldo'
    )
        INSERT INTO Notificaciones.TipoNotificacion (Nombre)
        VALUES ('actualizacion_sueldo');

    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID
    FROM Notificaciones.TipoNotificacion
    WHERE Nombre = 'actualizacion_sueldo';

    INSERT INTO Notificaciones.Notificacion
        (PersonaID, TipoNotificacionID, Mensaje)
    SELECT
        i.EmpleadoID,
        @TipoID,
        'Tu sueldo base fue actualizado a Bs ' +
        CAST(i.SueldoBase AS VARCHAR) +
        ' a partir del ' +
        FORMAT(i.FechaInicio, 'dd/MM/yyyy') + '.'
    FROM inserted i;
END;
GO