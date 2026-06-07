-- COCO Salón de Belleza · SalonBelleza_DB
-- 14 · STORED PROCEDURES · MÓDULO ADMINISTRADOR

USE SalonBelleza_DB;
GO

-- 1. Resumen general
--    RS[0] Ventas del mes  RS[1] Citas del mes  RS[2] Total clientes
--    RS[3] Alertas stock   RS[4] Ingresos 6 meses  RS[5] Top 5 servicios
CREATE OR ALTER PROCEDURE Admin.SP_ResumenGeneral
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS TotalVentas, ISNULL(SUM(p.Monto), 0) AS TotalIngresos,
           ISNULL(AVG(p.Monto), 0) AS TicketPromedio
    FROM Ventas.Venta v JOIN Ventas.Pago p ON p.VentaID = v.VentaID
    WHERE MONTH(v.Fecha) = MONTH(GETDATE()) AND YEAR(v.Fecha) = YEAR(GETDATE());

    SELECT COUNT(*) AS TotalCitas,
        SUM(CASE WHEN EstadoID = 11 THEN 1 ELSE 0 END) AS Completadas,
        SUM(CASE WHEN EstadoID = 12 THEN 1 ELSE 0 END) AS Canceladas
    FROM Agenda.Cita
    WHERE MONTH(FechaInicio) = MONTH(GETDATE()) AND YEAR(FechaInicio) = YEAR(GETDATE());

    SELECT COUNT(*) AS TotalClientes FROM Ventas.Cliente;

    SELECT COUNT(*) AS ProductosBajoStock FROM Inventario.Producto
    WHERE StockActual <= StockMinimo AND Activo = 1;

    SELECT YEAR(v.Fecha) AS Anio, MONTH(v.Fecha) AS Mes,
           ISNULL(SUM(p.Monto), 0) AS Ingresos, COUNT(v.VentaID) AS Ventas
    FROM Ventas.Venta v JOIN Ventas.Pago p ON p.VentaID = v.VentaID
    WHERE v.Fecha >= DATEADD(MONTH, -6, GETDATE())
    GROUP BY YEAR(v.Fecha), MONTH(v.Fecha)
    ORDER BY Anio ASC, Mes ASC;

    SELECT TOP 5
        s.Nombre AS Servicio,
        SUM(vds.Cantidad) AS TotalVeces,
        ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad), 0) AS TotalIngresos
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta                v  ON v.VentaID    = vds.VentaID
    JOIN Servicios.Servicio          s  ON s.ServicioID = vds.ServicioID
    WHERE MONTH(v.Fecha) = MONTH(GETDATE()) AND YEAR(v.Fecha) = YEAR(GETDATE())
    GROUP BY vds.ServicioID, s.Nombre
    ORDER BY TotalVeces DESC;
END;
GO

-- 2. Reporte de ventas
--    RS[0] Por empleado  RS[1] Por servicio  RS[2] Totales generales
--    Comisiones desde VentaDetalleServicio para evitar duplicados por rol
CREATE OR ALTER PROCEDURE Admin.SP_ReporteVentas
    @FechaInicio DATE = NULL,
    @FechaFin    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FI DATE = ISNULL(@FechaInicio, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1));
    DECLARE @FF DATE = ISNULL(@FechaFin, GETDATE());

    SELECT
        p.Nombre AS NombreEmpleado, p.Apellido AS ApellidoEmpleado,
        (SELECT STRING_AGG(NombreRol, ' / ')
         FROM (SELECT DISTINCT r2.NombreRol FROM RRHH.EmpleadoRol er2
               JOIN RRHH.Rol r2 ON r2.RolID = er2.RolID
               WHERE er2.EmpleadoID = vds.EmpleadoID) t) AS NombreRol,
        COUNT(DISTINCT vds.VentaID) AS TotalVentas,
        ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad), 0) AS TotalIngresos,
        ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0), 0) AS TotalComision
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta                v  ON v.VentaID     = vds.VentaID
    JOIN Personas.Persona            p  ON p.PersonaID   = vds.EmpleadoID
    JOIN RRHH.EmpleadoRol            er ON er.EmpleadoID = vds.EmpleadoID
    JOIN RRHH.Rol                    r  ON r.RolID       = er.RolID
    LEFT JOIN RRHH.EmpleadoComision  ec ON ec.EmpleadoID = vds.EmpleadoID AND ec.FechaFin IS NULL
    WHERE CAST(v.Fecha AS DATE) BETWEEN @FI AND @FF AND vds.EmpleadoID IS NOT NULL
    GROUP BY vds.EmpleadoID, p.Nombre, p.Apellido
    ORDER BY TotalIngresos DESC;

    SELECT s.Nombre AS Servicio, cat.Nombre AS Categoria,
           SUM(vds.Cantidad) AS TotalVeces,
           ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad), 0) AS TotalIngresos
    FROM Ventas.VentaDetalleServicio    vds
    JOIN Ventas.Venta                   v   ON v.VentaID         = vds.VentaID
    JOIN Servicios.Servicio             s   ON s.ServicioID      = vds.ServicioID
    JOIN Servicios.SubcategoriaServicio sc  ON sc.SubcategoriaID = s.SubcategoriaID
    JOIN Servicios.CategoriaServicio    cat ON cat.CategoriaID   = sc.CategoriaID
    WHERE CAST(v.Fecha AS DATE) BETWEEN @FI AND @FF
    GROUP BY vds.ServicioID, s.Nombre, cat.Nombre
    ORDER BY TotalVeces DESC;

    SELECT ISNULL(SUM(pg.Monto), 0) AS TotalIngresos,
           COUNT(DISTINCT v.VentaID) AS TotalVentas,
           ISNULL(AVG(pg.Monto), 0) AS TicketPromedio
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID = v.VentaID
    WHERE CAST(v.Fecha AS DATE) BETWEEN @FI AND @FF;
END;
GO

-- 3. Listar empleados
CREATE OR ALTER PROCEDURE RRHH.SP_ListarEmpleados
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.EmpleadoID, p.Nombre, p.Apellido, p.Email, p.Telefono, p.FechaNacimiento,
           p.Activo AS PersonaActiva,
           STRING_AGG(r.NombreRol, ', ') WITHIN GROUP (ORDER BY r.RolID) AS Roles,
           STRING_AGG(CAST(r.RolID AS VARCHAR), ',') WITHIN GROUP (ORDER BY r.RolID) AS RoleIDs,
           MIN(r.RolID) AS RolID, MIN(r.NombreRol) AS NombreRol,
           e.FechaContratacion, e.Activo,
           ISNULL(es.SueldoBase, 0) AS SueldoBase,
           ISNULL(ec.Porcentaje, 0) AS PorcentajeComision
    FROM RRHH.Empleado             e
    JOIN Personas.Persona           p  ON p.PersonaID   = e.EmpleadoID
    JOIN RRHH.EmpleadoRol           er ON er.EmpleadoID = e.EmpleadoID
    JOIN RRHH.Rol                   r  ON r.RolID       = er.RolID
    LEFT JOIN RRHH.EmpleadoSueldo   es ON es.EmpleadoID = e.EmpleadoID AND es.FechaFin IS NULL
    LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID = e.EmpleadoID AND ec.FechaFin IS NULL
    GROUP BY e.EmpleadoID, p.Nombre, p.Apellido, p.Email, p.Telefono,
             p.FechaNacimiento, p.Activo, e.FechaContratacion, e.Activo,
             es.SueldoBase, ec.Porcentaje
    ORDER BY MIN(r.RolID), p.Nombre;
END;
GO

-- 4. Listar empleados sin administradores
CREATE OR ALTER PROCEDURE RRHH.SP_ListarEmpleadosSinAdmin
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.EmpleadoID, p.Nombre, p.Apellido, p.Email, p.Telefono, p.FechaNacimiento,
           STRING_AGG(r.NombreRol, ', ') WITHIN GROUP (ORDER BY r.RolID) AS Roles,
           STRING_AGG(CAST(r.RolID AS VARCHAR), ',') WITHIN GROUP (ORDER BY r.RolID) AS RoleIDs,
           MIN(r.RolID) AS RolID, MIN(r.NombreRol) AS NombreRol,
           e.FechaContratacion, e.Activo,
           ISNULL(es.SueldoBase, 0) AS SueldoBase,
           ISNULL(ec.Porcentaje, 0) AS PorcentajeComision
    FROM RRHH.Empleado             e
    JOIN Personas.Persona           p  ON p.PersonaID   = e.EmpleadoID
    JOIN RRHH.EmpleadoRol           er ON er.EmpleadoID = e.EmpleadoID
    JOIN RRHH.Rol                   r  ON r.RolID       = er.RolID
    LEFT JOIN RRHH.EmpleadoSueldo   es ON es.EmpleadoID = e.EmpleadoID AND es.FechaFin IS NULL
    LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID = e.EmpleadoID AND ec.FechaFin IS NULL
    WHERE e.EmpleadoID NOT IN (
        SELECT er2.EmpleadoID FROM RRHH.EmpleadoRol er2 WHERE er2.RolID = 2
    )
    GROUP BY e.EmpleadoID, p.Nombre, p.Apellido, p.Email, p.Telefono,
             p.FechaNacimiento, e.FechaContratacion, e.Activo, es.SueldoBase, ec.Porcentaje
    ORDER BY MIN(r.RolID), p.Nombre;
END;
GO

-- 5. Listar roles del personal (sin dueña ni admin)
CREATE OR ALTER PROCEDURE RRHH.SP_ListarRolesPersonal
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RolID, NombreRol FROM RRHH.Rol WHERE RolID NOT IN (1,2) ORDER BY RolID;
END;
GO

-- 6. Registrar empleado
--    Crea Persona, Empleado, Rol laboral, Usuario, Rol de seguridad,
--    Sueldo, Comisión y Horario estándar (Lun–Sáb)
CREATE OR ALTER PROCEDURE RRHH.SP_RegistrarEmpleado
    @Nombre        VARCHAR(100),
    @Apellido      VARCHAR(100),
    @Telefono      VARCHAR(20),
    @Email         VARCHAR(100),
    @PassHash      VARCHAR(255),
    @RolID         INT,
    @FechaContrato DATE,
    @SueldoBase    DECIMAL(10,2),
    @PctComision   DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email = @Email)
        BEGIN ROLLBACK; RAISERROR('Este correo ya está registrado.',16,1); RETURN; END

        DECLARE @PersonaID INT;
        INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email) VALUES (@Nombre,@Apellido,@Telefono,@Email);
        SET @PersonaID = SCOPE_IDENTITY();

        INSERT INTO RRHH.Empleado (EmpleadoID,FechaContratacion,Activo) VALUES (@PersonaID,@FechaContrato,1);
        INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID) VALUES (@PersonaID,@RolID);

        DECLARE @UsuarioID INT;
        INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@PersonaID,@Email,@PassHash);
        SET @UsuarioID = SCOPE_IDENTITY();

        -- Recepcionista (7) → Atención y soporte (4); técnicos → Personal técnico (5)
        IF @RolID = 7
            INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UsuarioID,4);
        ELSE
            INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UsuarioID,5);

        INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@PersonaID,@SueldoBase,@FechaContrato);
        INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@PersonaID,@PctComision,@FechaContrato);
        INSERT INTO RRHH.HorarioEmpleado (EmpleadoID,DiaSemana,HoraEntrada,HoraSalida,Activo) VALUES
            (@PersonaID,1,'09:00','19:00',1),(@PersonaID,2,'09:00','19:00',1),
            (@PersonaID,3,'09:00','19:00',1),(@PersonaID,4,'09:00','19:00',1),
            (@PersonaID,5,'09:00','19:00',1),(@PersonaID,6,'09:00','14:00',1);

        COMMIT;
        SELECT @PersonaID AS EmpleadoID, 'Empleado registrado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @Error VARCHAR(500) = ERROR_MESSAGE();
        RAISERROR(@Error,16,1);
    END CATCH
END;
GO

-- 7. Actualizar empleado
CREATE OR ALTER PROCEDURE RRHH.SP_ActualizarEmpleado
    @EmpleadoID      INT,
    @Nombre          VARCHAR(100),
    @Apellido        VARCHAR(100),
    @Telefono        VARCHAR(20),
    @Email           VARCHAR(100),
    @FechaNacimiento DATE          = NULL,
    @Activo          BIT,
    @NuevoSueldo     DECIMAL(10,2) = NULL,
    @NuevoPct        DECIMAL(5,2)  = NULL,
    @RoleIDs         VARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email = @Email AND PersonaID <> @EmpleadoID)
        BEGIN ROLLBACK; RAISERROR('Este correo ya está en uso.', 16, 1); RETURN; END

        UPDATE Personas.Persona
        SET Nombre=@Nombre, Apellido=@Apellido, Telefono=@Telefono,
            Email=@Email, FechaNacimiento=@FechaNacimiento
        WHERE PersonaID = @EmpleadoID;

        UPDATE RRHH.Empleado SET Activo = @Activo WHERE EmpleadoID = @EmpleadoID;
        UPDATE Seguridad.Usuario SET Username=@Email, Activo=@Activo WHERE PersonaID = @EmpleadoID;

        IF @NuevoSueldo IS NOT NULL
        BEGIN
            UPDATE RRHH.EmpleadoSueldo SET FechaFin = GETDATE() WHERE EmpleadoID = @EmpleadoID AND FechaFin IS NULL;
            INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@EmpleadoID,@NuevoSueldo,GETDATE());
        END

        IF @NuevoPct IS NOT NULL
        BEGIN
            UPDATE RRHH.EmpleadoComision SET FechaFin = GETDATE() WHERE EmpleadoID = @EmpleadoID AND FechaFin IS NULL;
            INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@EmpleadoID,@NuevoPct,GETDATE());
        END

        IF @RoleIDs IS NOT NULL
        BEGIN
            DELETE FROM RRHH.EmpleadoRol WHERE EmpleadoID = @EmpleadoID;
            INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID)
            SELECT @EmpleadoID, CAST(value AS INT) FROM STRING_SPLIT(@RoleIDs,',')
            WHERE LTRIM(RTRIM(value)) <> '';
        END

        COMMIT;
        SELECT 'Empleado actualizado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @Error VARCHAR(500) = ERROR_MESSAGE();
        RAISERROR(@Error,16,1);
    END CATCH
END;
GO

-- 8. Roles de un empleado
CREATE OR ALTER PROCEDURE RRHH.SP_ObtenerRolesEmpleado
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT r.RolID, r.NombreRol FROM RRHH.EmpleadoRol er
    JOIN RRHH.Rol r ON r.RolID = er.RolID
    WHERE er.EmpleadoID = @EmpleadoID ORDER BY r.RolID;
END;
GO

-- 9. Actualizar sueldo
CREATE OR ALTER PROCEDURE RRHH.SP_ActualizarSueldo
    @EmpleadoID  INT,
    @NuevoSueldo DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE RRHH.EmpleadoSueldo SET FechaFin = CAST(GETDATE() AS DATE)
        WHERE EmpleadoID = @EmpleadoID AND FechaFin IS NULL;
        INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio)
        VALUES (@EmpleadoID,@NuevoSueldo,CAST(GETDATE() AS DATE));
        COMMIT;
        SELECT 'Sueldo actualizado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar el sueldo.', 16, 1);
    END CATCH
END;
GO

-- 10. Actualizar comisión
CREATE OR ALTER PROCEDURE RRHH.SP_ActualizarComision
    @EmpleadoID INT,
    @NuevoPct   DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE RRHH.EmpleadoComision SET FechaFin = CAST(GETDATE() AS DATE)
        WHERE EmpleadoID = @EmpleadoID AND FechaFin IS NULL;
        INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio)
        VALUES (@EmpleadoID,@NuevoPct,CAST(GETDATE() AS DATE));
        COMMIT;
        SELECT 'Comisión actualizada correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar la comisión.', 16, 1);
    END CATCH
END;
GO

-- 11. Nómina del mes
--    Comisiones desde VentaDetalleServicio.EmpleadoID
CREATE OR ALTER PROCEDURE RRHH.SP_NominaDelMes
    @Anio INT = NULL,
    @Mes  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AnioFiltro INT = ISNULL(@Anio, YEAR(GETDATE()));
    DECLARE @MesFiltro  INT = ISNULL(@Mes,  MONTH(GETDATE()));
    DECLARE @Periodo    VARCHAR(7) = CAST(@AnioFiltro AS VARCHAR) + '-' + RIGHT('0'+CAST(@MesFiltro AS VARCHAR),2);

    SELECT e.EmpleadoID, p.Nombre, p.Apellido, r.NombreRol, r.RolID,
           ISNULL(es.SueldoBase, 0) AS SueldoBase,
           ISNULL(ec.Porcentaje, 0) AS PorcentajeComision,
           ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad), 0) AS TotalVentas,
           ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0), 0) AS TotalComision,
           ISNULL(es.SueldoBase, 0) +
           ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0), 0) AS TotalNomina,
           CASE WHEN pn.PagoNominaID IS NOT NULL THEN 1 ELSE 0 END AS YaPagado,
           pn.FechaPago, pn.Total AS MontoPagado, @Periodo AS Periodo,
           CASE WHEN r.RolID IN (1,2) THEN 1 ELSE 0 END AS PagadoPorDuena
    FROM RRHH.Empleado              e
    JOIN Personas.Persona            p  ON p.PersonaID   = e.EmpleadoID
    JOIN RRHH.EmpleadoRol            er ON er.EmpleadoID = e.EmpleadoID
    JOIN RRHH.Rol                    r  ON r.RolID       = er.RolID
    LEFT JOIN RRHH.EmpleadoSueldo    es ON es.EmpleadoID = e.EmpleadoID AND es.FechaFin IS NULL
    LEFT JOIN RRHH.EmpleadoComision  ec ON ec.EmpleadoID = e.EmpleadoID AND ec.FechaFin IS NULL
    LEFT JOIN Ventas.VentaDetalleServicio vds ON vds.EmpleadoID = e.EmpleadoID
        AND EXISTS (SELECT 1 FROM Ventas.Venta v WHERE v.VentaID = vds.VentaID
                    AND MONTH(v.Fecha) = @MesFiltro AND YEAR(v.Fecha) = @AnioFiltro)
    LEFT JOIN RRHH.PagoNomina        pn ON pn.EmpleadoID = e.EmpleadoID AND pn.Periodo = @Periodo
    WHERE e.Activo = 1 AND r.RolID IN (3,4,5,6)
    GROUP BY e.EmpleadoID, p.Nombre, p.Apellido, r.NombreRol, r.RolID,
             es.SueldoBase, ec.Porcentaje, pn.PagoNominaID, pn.FechaPago, pn.Total
    ORDER BY r.RolID, p.Nombre;
END;
GO

-- 12. Registrar pago de nómina
CREATE OR ALTER PROCEDURE RRHH.SP_RegistrarPagoNomina
    @EmpleadoID  INT,
    @Periodo     VARCHAR(7),
    @MontoPagado DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM RRHH.EmpleadoRol WHERE EmpleadoID = @EmpleadoID AND RolID IN (3,4,5,6,7))
        BEGIN ROLLBACK; RAISERROR('Solo puedes pagar al personal técnico y de atención.', 16, 1); RETURN; END

        IF EXISTS (SELECT 1 FROM RRHH.PagoNomina WHERE EmpleadoID = @EmpleadoID AND Periodo = @Periodo)
        BEGIN ROLLBACK; RAISERROR('Este período ya fue pagado.', 16, 1); RETURN; END

        DECLARE @SueldoBase DECIMAL(10,2);
        SELECT @SueldoBase = ISNULL(SueldoBase, 0) FROM RRHH.EmpleadoSueldo
        WHERE EmpleadoID = @EmpleadoID AND FechaFin IS NULL;

        DECLARE @Comision DECIMAL(10,2);
        SELECT @Comision = ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0), 0)
        FROM Ventas.VentaDetalleServicio vds
        JOIN Ventas.Venta                v  ON v.VentaID     = vds.VentaID
        JOIN RRHH.EmpleadoComision       ec ON ec.EmpleadoID = vds.EmpleadoID AND ec.FechaFin IS NULL
        WHERE vds.EmpleadoID = @EmpleadoID
          AND LEFT(CONVERT(VARCHAR, v.Fecha, 120), 7) = @Periodo;

        INSERT INTO RRHH.PagoNomina (EmpleadoID,Periodo,SueldoBase,Comision,FechaPago,Pagado)
        VALUES (@EmpleadoID,@Periodo,@SueldoBase,@Comision,GETDATE(),1);
        COMMIT;
        SELECT 'Pago registrado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al registrar el pago.', 16, 1);
    END CATCH
END;
GO

-- 13. Inventario
CREATE OR ALTER PROCEDURE Inventario.SP_ObtenerInventario
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.ProductoID, p.Nombre, p.StockActual, p.StockMinimo, p.Activo,
           pv.Nombre AS Proveedor, ISNULL(pp.Precio, 0) AS Precio,
           CASE WHEN p.StockActual <= 0 THEN 'Sin stock'
                WHEN p.StockActual <= p.StockMinimo THEN 'Stock bajo'
                ELSE 'Normal' END AS EstadoStock
    FROM Inventario.Producto      p
    LEFT JOIN Inventario.ProductoPrecio    pp  ON pp.ProductoID = p.ProductoID AND pp.FechaFin IS NULL
    LEFT JOIN Inventario.ProductoProveedor ppv ON ppv.ProductoID = p.ProductoID
    LEFT JOIN Inventario.Proveedor         pv  ON pv.ProveedorID = ppv.ProveedorID
    WHERE p.Activo = 1
    ORDER BY CASE WHEN p.StockActual <= p.StockMinimo THEN 0 ELSE 1 END, p.Nombre;
END;
GO

-- 14. Ajustar stock
--    @Tipo: 'entrada' | 'salida' | 'ajuste'
CREATE OR ALTER PROCEDURE Inventario.SP_AjustarStock
    @ProductoID INT,
    @Cantidad   INT,
    @Tipo       VARCHAR(20),
    @Motivo     VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @EsEntrada BIT = CASE WHEN @Tipo IN ('entrada','ajuste') THEN 1 ELSE 0 END;
        IF @Tipo = 'entrada'
            UPDATE Inventario.Producto SET StockActual = StockActual + @Cantidad WHERE ProductoID = @ProductoID;
        ELSE IF @Tipo = 'ajuste'
            UPDATE Inventario.Producto SET StockActual = @Cantidad WHERE ProductoID = @ProductoID;
        ELSE IF @Tipo = 'salida'
        BEGIN
            IF (SELECT StockActual FROM Inventario.Producto WHERE ProductoID = @ProductoID) < @Cantidad
            BEGIN ROLLBACK; RAISERROR('Stock insuficiente.', 16, 1); RETURN; END
            UPDATE Inventario.Producto SET StockActual = StockActual - @Cantidad WHERE ProductoID = @ProductoID;
        END
        INSERT INTO Inventario.MovimientoInventario (ProductoID,EsEntrada,Cantidad,Fecha)
        VALUES (@ProductoID,@EsEntrada,@Cantidad,GETDATE());
        COMMIT;
        SELECT 'Stock actualizado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al ajustar el stock.', 16, 1);
    END CATCH
END;
GO

-- 15. Servicios
CREATE OR ALTER PROCEDURE Servicios.SP_ListarServicios
AS
BEGIN
    SET NOCOUNT ON;
    SELECT s.ServicioID, s.Nombre, s.Descripcion, s.DuracionMin, s.Activo,
           cat.Nombre AS Categoria, sc.Nombre AS Subcategoria,
           ISNULL(sp.Precio, 0) AS Precio, sp.FechaInicio AS PrecioDesde
    FROM Servicios.Servicio             s
    JOIN Servicios.SubcategoriaServicio sc  ON sc.SubcategoriaID = s.SubcategoriaID
    JOIN Servicios.CategoriaServicio    cat ON cat.CategoriaID   = sc.CategoriaID
    LEFT JOIN Servicios.ServicioPrecio  sp  ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
    ORDER BY cat.Nombre, sc.Nombre, s.Nombre;
END;
GO

-- 16. Actualizar precio de servicio
CREATE OR ALTER PROCEDURE Servicios.SP_ActualizarPrecio
    @ServicioID  INT,
    @NuevoPrecio DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Servicios.ServicioPrecio SET FechaFin = CAST(GETDATE() AS DATE)
        WHERE ServicioID = @ServicioID AND FechaFin IS NULL;
        INSERT INTO Servicios.ServicioPrecio (ServicioID,Precio,FechaInicio)
        VALUES (@ServicioID,@NuevoPrecio,CAST(GETDATE() AS DATE));
        COMMIT;
        SELECT 'Precio actualizado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar el precio.', 16, 1);
    END CATCH
END;
GO

-- 17. Promociones
CREATE OR ALTER PROCEDURE Marketing.SP_ListarPromociones
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PromocionID, p.Nombre, p.Descripcion, p.Descuento,
           p.FechaInicio, p.FechaFin, p.Activo,
           CASE WHEN GETDATE() BETWEEN p.FechaInicio AND p.FechaFin THEN 'Activa'
                WHEN GETDATE() < p.FechaInicio THEN 'Próxima' ELSE 'Vencida' END AS Estado,
           COUNT(ps.ServicioID) AS TotalServicios
    FROM Marketing.Promocion        p
    LEFT JOIN Marketing.PromocionServicio ps ON ps.PromocionID = p.PromocionID
    GROUP BY p.PromocionID, p.Nombre, p.Descripcion, p.Descuento,
             p.FechaInicio, p.FechaFin, p.Activo
    ORDER BY p.FechaInicio DESC;
END;
GO

CREATE OR ALTER PROCEDURE Marketing.SP_CrearPromocion
    @Nombre      VARCHAR(100),
    @Descripcion VARCHAR(300),
    @Descuento   DECIMAL(5,2),
    @FechaInicio DATE,
    @FechaFin    DATE,
    @ServicioIDs VARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @PromocionID INT;
        INSERT INTO Marketing.Promocion (Nombre,Descripcion,Descuento,FechaInicio,FechaFin,Activo)
        VALUES (@Nombre,@Descripcion,@Descuento,@FechaInicio,@FechaFin,1);
        SET @PromocionID = SCOPE_IDENTITY();

        IF @ServicioIDs IS NOT NULL
        BEGIN
            INSERT INTO Marketing.PromocionServicio (PromocionID,ServicioID)
            SELECT @PromocionID, CAST(value AS INT) FROM STRING_SPLIT(@ServicioIDs,',')
            WHERE LTRIM(RTRIM(value)) <> '';
        END
        COMMIT;
        SELECT @PromocionID AS PromocionID, 'Promoción creada correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al crear la promoción.', 16, 1);
    END CATCH
END;
GO

-- 18. Perfil del administrador
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerPerfilRecepcion
    @PersonaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.PersonaID,
        p.Nombre,
        p.Apellido,
        p.Email,
        p.Telefono,
        p.FechaNacimiento,
        r.Nombre AS NombreRol
    FROM Personas.Persona      p
    JOIN Seguridad.Usuario      u  ON u.PersonaID  = p.PersonaID
    JOIN Seguridad.UsuarioRol   ur ON ur.UsuarioID = u.UsuarioID
    JOIN Seguridad.Rol          r  ON r.RolID      = ur.RolID
    WHERE p.PersonaID = @PersonaID;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ActualizarPerfilRecepcion
    @PersonaID       INT,
    @Nombre          VARCHAR(100),
    @Apellido        VARCHAR(100),
    @Telefono        VARCHAR(20),
    @Email           VARCHAR(100),
    @FechaNacimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email = @Email AND PersonaID <> @PersonaID)
        BEGIN ROLLBACK; RAISERROR('Este correo ya está en uso.', 16, 1); RETURN; END

        UPDATE Personas.Persona
        SET Nombre=@Nombre, Apellido=@Apellido, Telefono=@Telefono,
            Email=@Email, FechaNacimiento=@FechaNacimiento
        WHERE PersonaID = @PersonaID;

        UPDATE Seguridad.Usuario SET Username=@Email WHERE PersonaID = @PersonaID;
        COMMIT;
        SELECT 'Perfil actualizado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar perfil.', 16, 1);
    END CATCH
END;
GO

-- 19. Sincronizar roles de seguridad según roles laborales
CREATE OR ALTER PROCEDURE RRHH.SP_SincronizarRolesSeguridad
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EmpleadoID INT, @UsuarioID INT;
    DECLARE cur CURSOR FOR
        SELECT e.EmpleadoID, u.UsuarioID FROM RRHH.Empleado e
        JOIN Seguridad.Usuario u ON u.PersonaID = e.EmpleadoID WHERE e.Activo = 1;
    OPEN cur;
    FETCH NEXT FROM cur INTO @EmpleadoID, @UsuarioID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DELETE FROM Seguridad.UsuarioRol WHERE UsuarioID = @UsuarioID AND RolID IN (4,5);

        IF EXISTS (SELECT 1 FROM RRHH.EmpleadoRol WHERE EmpleadoID = @EmpleadoID AND RolID IN (3,4,5,6))
            INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UsuarioID,5);
        IF EXISTS (SELECT 1 FROM RRHH.EmpleadoRol WHERE EmpleadoID = @EmpleadoID AND RolID = 7)
            INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UsuarioID,4);

        FETCH NEXT FROM cur INTO @EmpleadoID, @UsuarioID;
    END
    CLOSE cur; DEALLOCATE cur;
    SELECT 'Roles sincronizados correctamente.' AS Mensaje;
END;
GO