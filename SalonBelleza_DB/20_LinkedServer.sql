-- Linked Server

USE SalonBelleza_DB;
GO

-- Eliminar server previo
EXEC sp_dropserver 'CBB_NODE', 'droplogins';
GO

-- Crear nuevo server
EXEC sp_addlinkedserver 
    @server = 'CBB_NODE',
    @srvproduct = '',
    @provider = 'SQLNCLI11',
    @datasrc = '10.147.26.73';

-- Crear login 
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'CBB_NODE',
    @useself = 'FALSE',
    @rmtuser = 'sa',
    @rmtpassword = 'Coco2025!';
GO

-- Validación de tablas remotas
SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM CBB_NODE.SalonBelleza_CBB.INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_SCHEMA, TABLE_NAME;
GO


-- Cambiar modo de autenticación
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode',
    REG_DWORD,
    2;
GO

-- Habilitar login sa
ALTER LOGIN sa ENABLE;
GO

ALTER LOGIN sa
WITH PASSWORD = 'Coco2025!';
GO


-- Validación SCZ - CBBA
SELECT
    'Santa Cruz' AS Nodo,
    TABLE_SCHEMA COLLATE SQL_Latin1_General_CP1_CI_AS AS TABLE_SCHEMA,
    TABLE_NAME   COLLATE SQL_Latin1_General_CP1_CI_AS AS TABLE_NAME
FROM SalonBelleza_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'

UNION ALL

SELECT
    'Cochabamba' AS Nodo,
    TABLE_SCHEMA COLLATE SQL_Latin1_General_CP1_CI_AS AS TABLE_SCHEMA,
    TABLE_NAME   COLLATE SQL_Latin1_General_CP1_CI_AS AS TABLE_NAME
FROM CBB_NODE.SalonBelleza_CBB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'

ORDER BY Nodo, TABLE_SCHEMA, TABLE_NAME;
GO


-- Change tracking

USE SalonBelleza_DB;
GO

-- Habilitar Change tracking 
ALTER DATABASE SalonBelleza_DB
SET CHANGE_TRACKING = ON
(
    CHANGE_RETENTION = 2 DAYS,
    AUTO_CLEANUP = ON
);
GO

-- Habilitar Change tracking en tablas replicadas 
ALTER TABLE Servicios.CategoriaServicio
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Servicios.SubcategoriaServicio
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Servicios.Servicio
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Servicios.ServicioPrecio
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Marketing.Promocion
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Marketing.PromocionServicio
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Inventario.Producto
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Inventario.ProductoPrecio
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Inventario.Proveedor
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Ventas.MetodoPago
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Agenda.EstadoCita
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE RRHH.Rol
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Seguridad.Rol
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Notificaciones.TipoNotificacion
    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
GO


-- SP: Sincronización de tablas
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE dbo.SP_SincronizarReplicadas
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CategoriaID INT, @Nombre VARCHAR(100);
    DECLARE @SubcategoriaID INT, @NombreSub VARCHAR(100), @CatID INT;
    DECLARE @ServicioID INT, @NombreS VARCHAR(150), @DuracionMin INT,
            @SubcategoriaID2 INT, @Descripcion VARCHAR(255), @Activo BIT;
    DECLARE @ServicioPrecioID INT, @SrvID INT, @Precio DECIMAL(10,2),
            @FechaInicio DATE, @FechaFin DATE;
    DECLARE @PromocionID INT, @NombreP VARCHAR(100), @DescripcionP VARCHAR(255),
            @FechaInicioP DATE, @FechaFinP DATE, @Descuento DECIMAL(5,2),
            @ActivoP BIT, @TipoPromocion VARCHAR(20);

    -- 1. CategoriaServicio
    DECLARE cur_cat CURSOR FOR SELECT CategoriaID, Nombre FROM Servicios.CategoriaServicio;
    OPEN cur_cat;
    FETCH NEXT FROM cur_cat INTO @CategoriaID, @Nombre;
    WHILE @@FETCH_STATUS=0
    BEGIN
        EXEC CBB_NODE.SalonBelleza_CBB.dbo.SP_InsertarCategoria @CategoriaID, @Nombre;
        FETCH NEXT FROM cur_cat INTO @CategoriaID, @Nombre;
    END;
    CLOSE cur_cat; DEALLOCATE cur_cat;

    -- 2. SubcategoriaServicio
    DECLARE cur_sub CURSOR FOR SELECT SubcategoriaID, CategoriaID, Nombre FROM Servicios.SubcategoriaServicio;
    OPEN cur_sub;
    FETCH NEXT FROM cur_sub INTO @SubcategoriaID, @CatID, @NombreSub;
    WHILE @@FETCH_STATUS=0
    BEGIN
        EXEC CBB_NODE.SalonBelleza_CBB.dbo.SP_InsertarSubcategoria @SubcategoriaID, @CatID, @NombreSub;
        FETCH NEXT FROM cur_sub INTO @SubcategoriaID, @CatID, @NombreSub;
    END;
    CLOSE cur_sub; DEALLOCATE cur_sub;

    -- 3. Servicio
    DECLARE cur_servicio CURSOR FOR
        SELECT ServicioID, Nombre, DuracionMin, SubcategoriaID, Descripcion, Activo FROM Servicios.Servicio;
    OPEN cur_servicio;
    FETCH NEXT FROM cur_servicio INTO @ServicioID, @NombreS, @DuracionMin, @SubcategoriaID2, @Descripcion, @Activo;
    WHILE @@FETCH_STATUS=0
    BEGIN
        EXEC CBB_NODE.SalonBelleza_CBB.dbo.SP_InsertarServicio
            @ServicioID, @NombreS, @DuracionMin, @SubcategoriaID2, @Descripcion, @Activo;
        FETCH NEXT FROM cur_servicio INTO @ServicioID, @NombreS, @DuracionMin, @SubcategoriaID2, @Descripcion, @Activo;
    END;
    CLOSE cur_servicio; DEALLOCATE cur_servicio;

    -- 4. ServicioPrecio
    DECLARE cur_precio CURSOR FOR
        SELECT ServicioPrecioID, ServicioID, Precio, FechaInicio, FechaFin FROM Servicios.ServicioPrecio;
    OPEN cur_precio;
    FETCH NEXT FROM cur_precio INTO @ServicioPrecioID, @SrvID, @Precio, @FechaInicio, @FechaFin;
    WHILE @@FETCH_STATUS=0
    BEGIN
        EXEC CBB_NODE.SalonBelleza_CBB.dbo.SP_InsertarServicioPrecio
            @ServicioPrecioID, @SrvID, @Precio, @FechaInicio, @FechaFin;
        FETCH NEXT FROM cur_precio INTO @ServicioPrecioID, @SrvID, @Precio, @FechaInicio, @FechaFin;
    END;
    CLOSE cur_precio; DEALLOCATE cur_precio;

    -- 5. Promocion (solo globales y cumpleanos)
    DECLARE cur_promo CURSOR FOR
        SELECT PromocionID, Nombre, Descripcion, FechaInicio, FechaFin, Descuento, Activo, TipoPromocion
        FROM Marketing.Promocion
        WHERE TipoPromocion IN ('global', 'cumpleanos');
    OPEN cur_promo;
    FETCH NEXT FROM cur_promo INTO @PromocionID, @NombreP, @DescripcionP, @FechaInicioP, @FechaFinP, @Descuento, @ActivoP, @TipoPromocion;
    WHILE @@FETCH_STATUS=0
    BEGIN
        EXEC CBB_NODE.SalonBelleza_CBB.dbo.SP_InsertarPromocion
            @PromocionID, @NombreP, @DescripcionP, @FechaInicioP, @FechaFinP, @Descuento, @ActivoP, @TipoPromocion;
        FETCH NEXT FROM cur_promo INTO @PromocionID, @NombreP, @DescripcionP, @FechaInicioP, @FechaFinP, @Descuento, @ActivoP, @TipoPromocion;
    END;
    CLOSE cur_promo; DEALLOCATE cur_promo;

    PRINT 'Sincronizacion completada: Categoria, Subcategoria, Servicio, ServicioPrecio, Promociones globales';
END;
GO