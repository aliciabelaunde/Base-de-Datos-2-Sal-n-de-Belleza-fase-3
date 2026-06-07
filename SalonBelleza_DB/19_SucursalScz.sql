-- Conexiones

USE SalonBelleza_DB;
GO

-- Agregar columna de Scz
CREATE OR ALTER PROCEDURE dbo.sp_AgregarSucursal
    @SchemaName SYSNAME,
    @TableName  SYSNAME
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = @SchemaName
          AND TABLE_NAME   = @TableName
          AND COLUMN_NAME  = 'Sucursal'
    )
    BEGIN
        DECLARE @SQL NVARCHAR(MAX);

        SET @SQL = '
            ALTER TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '
            ADD Sucursal CHAR(3) NOT NULL DEFAULT ''SC'';
        ';

        EXEC sp_executesql @SQL;

        PRINT '✔ Columna Sucursal agregada en '
              + @SchemaName + '.' + @TableName;
    END
    ELSE
    BEGIN
        PRINT '• La columna ya existe en '
              + @SchemaName + '.' + @TableName;
    END
END;
GO

-- Módulo Personas
EXEC dbo.sp_AgregarSucursal 'Personas', 'Persona';
GO

-- Módulo RRHHH
EXEC dbo.sp_AgregarSucursal 'RRHH', 'Empleado';
EXEC dbo.sp_AgregarSucursal 'RRHH', 'HorarioEmpleado';
EXEC dbo.sp_AgregarSucursal 'RRHH', 'HorarioExcepcion';
EXEC dbo.sp_AgregarSucursal 'RRHH', 'PagoNomina';
GO

-- Módulo Ventas
EXEC dbo.sp_AgregarSucursal 'Ventas', 'Cliente';
EXEC dbo.sp_AgregarSucursal 'Ventas', 'ClienteDetalle';
EXEC dbo.sp_AgregarSucursal 'Ventas', 'Venta';
EXEC dbo.sp_AgregarSucursal 'Ventas', 'VentaDetalleProducto';
EXEC dbo.sp_AgregarSucursal 'Ventas', 'VentaDetalleServicio';
EXEC dbo.sp_AgregarSucursal 'Ventas', 'Pago';
GO

-- Módulo Agenda
EXEC dbo.sp_AgregarSucursal 'Agenda', 'Cita';
EXEC dbo.sp_AgregarSucursal 'Agenda', 'CitaServicio';
EXEC dbo.sp_AgregarSucursal 'Agenda', 'CitaEmpleado';
EXEC dbo.sp_AgregarSucursal 'Agenda', 'SolicitudEspecial';
GO

-- Módulo Facturación
EXEC dbo.sp_AgregarSucursal 'Facturacion', 'Factura';
GO

-- Módulo Seguridad
EXEC dbo.sp_AgregarSucursal 'Seguridad', 'Usuario';
GO

-- Módulo Notificaciones
EXEC dbo.sp_AgregarSucursal 'Notificaciones', 'Notificacion';
GO

-- Verificación final
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME = 'Sucursal'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
GO

-- Limpieza 
DROP PROCEDURE dbo.sp_AgregarSucursal;
GO

-- Finalización
PRINT '============================================================';
PRINT ' 02_SC_sucursal.sql ejecutado correctamente';
PRINT ' Nodo: Santa Cruz | SQL Server | SalonBelleza_DB';
PRINT ' Columna Sucursal = SC agregada correctamente';
PRINT ' a todas las tablas fragmentadas.';
PRINT '============================================================';
GO