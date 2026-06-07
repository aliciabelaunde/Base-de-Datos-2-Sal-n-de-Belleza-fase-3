-- COCO Salón de Belleza · SalonBelleza_DB
-- 14 · STORED PROCEDURES · MÓDULO DUEÑA

USE SalonBelleza_DB;
GO

-- 1. Resumen ejecutivo
--    RS[0] Ingresos comparativa  RS[1] Citas comparativa
--    RS[2] Clientes  RS[3] Equipo por rol
--    RS[4] Ingresos 12 meses  RS[5] Nómina mes  RS[6] Top 3 estilistas
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Duena.SP_ResumenEjecutivo
AS
BEGIN
    SET NOCOUNT ON;

    -- Ingresos combinados SC + CBB
    SELECT
        ISNULL(SUM(CASE WHEN MONTH(v.Fecha)=MONTH(GETDATE()) AND YEAR(v.Fecha)=YEAR(GETDATE()) THEN pg.Monto ELSE 0 END),0) +
        ISNULL((SELECT SUM(pg2.Monto) FROM CBB_NODE.SalonBelleza_CBB.Ventas.Venta v2
                JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Pago pg2 ON pg2.VentaID=v2.VentaID
                WHERE MONTH(v2.Fecha)=MONTH(GETDATE()) AND YEAR(v2.Fecha)=YEAR(GETDATE())),0) AS IngresosMesActual,
        ISNULL(SUM(CASE WHEN MONTH(v.Fecha)=MONTH(DATEADD(MONTH,-1,GETDATE())) AND YEAR(v.Fecha)=YEAR(DATEADD(MONTH,-1,GETDATE())) THEN pg.Monto ELSE 0 END),0) +
        ISNULL((SELECT SUM(pg2.Monto) FROM CBB_NODE.SalonBelleza_CBB.Ventas.Venta v2
                JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Pago pg2 ON pg2.VentaID=v2.VentaID
                WHERE MONTH(v2.Fecha)=MONTH(DATEADD(MONTH,-1,GETDATE())) AND YEAR(v2.Fecha)=YEAR(DATEADD(MONTH,-1,GETDATE()))),0) AS IngresosMesAnterior,
        ISNULL(SUM(CASE WHEN YEAR(v.Fecha)=YEAR(GETDATE()) THEN pg.Monto ELSE 0 END),0) +
        ISNULL((SELECT SUM(pg2.Monto) FROM CBB_NODE.SalonBelleza_CBB.Ventas.Venta v2
                JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Pago pg2 ON pg2.VentaID=v2.VentaID
                WHERE YEAR(v2.Fecha)=YEAR(GETDATE())),0) AS IngresosAnio,
        COUNT(DISTINCT CASE WHEN MONTH(v.Fecha)=MONTH(GETDATE()) AND YEAR(v.Fecha)=YEAR(GETDATE()) THEN v.VentaID END) +
        ISNULL((SELECT COUNT(DISTINCT v2.VentaID) FROM CBB_NODE.SalonBelleza_CBB.Ventas.Venta v2
                WHERE MONTH(v2.Fecha)=MONTH(GETDATE()) AND YEAR(v2.Fecha)=YEAR(GETDATE())),0) AS VentasMes,
        ISNULL(AVG(CASE WHEN YEAR(v.Fecha)=YEAR(GETDATE()) THEN pg.Monto END),0) AS TicketPromedio
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID;

    -- Citas combinadas SC + CBB
    SELECT
        SUM(CASE WHEN MONTH(FechaInicio)=MONTH(GETDATE()) AND YEAR(FechaInicio)=YEAR(GETDATE()) AND EstadoID=11 THEN 1 ELSE 0 END) +
        ISNULL((SELECT COUNT(*) FROM CBB_NODE.SalonBelleza_CBB.Agenda.Cita
                WHERE MONTH(FechaInicio)=MONTH(GETDATE()) AND YEAR(FechaInicio)=YEAR(GETDATE()) AND EstadoID=11),0) AS CitasMesActual,
        SUM(CASE WHEN MONTH(FechaInicio)=MONTH(DATEADD(MONTH,-1,GETDATE())) AND YEAR(FechaInicio)=YEAR(DATEADD(MONTH,-1,GETDATE())) AND EstadoID=11 THEN 1 ELSE 0 END) +
        ISNULL((SELECT COUNT(*) FROM CBB_NODE.SalonBelleza_CBB.Agenda.Cita
                WHERE MONTH(FechaInicio)=MONTH(DATEADD(MONTH,-1,GETDATE())) AND YEAR(FechaInicio)=YEAR(DATEADD(MONTH,-1,GETDATE())) AND EstadoID=11),0) AS CitasMesAnterior,
        SUM(CASE WHEN YEAR(FechaInicio)=YEAR(GETDATE()) AND EstadoID=11 THEN 1 ELSE 0 END) +
        ISNULL((SELECT COUNT(*) FROM CBB_NODE.SalonBelleza_CBB.Agenda.Cita
                WHERE YEAR(FechaInicio)=YEAR(GETDATE()) AND EstadoID=11),0) AS CitasAnio
    FROM Agenda.Cita;

    -- Clientes combinados SC + CBB
    SELECT
        COUNT(*) +
        ISNULL((SELECT COUNT(*) FROM CBB_NODE.SalonBelleza_CBB.Ventas.Cliente),0) AS TotalClientes,
        SUM(CASE WHEN MONTH(p.FechaRegistro)=MONTH(GETDATE()) AND YEAR(p.FechaRegistro)=YEAR(GETDATE()) THEN 1 ELSE 0 END) +
        ISNULL((SELECT COUNT(*) FROM CBB_NODE.SalonBelleza_CBB.Ventas.Cliente cl2
                JOIN CBB_NODE.SalonBelleza_CBB.Personas.Persona p2 ON p2.PersonaID=cl2.ClienteID
                WHERE MONTH(p2.FechaRegistro)=MONTH(GETDATE()) AND YEAR(p2.FechaRegistro)=YEAR(GETDATE())),0) AS NuevosMes
    FROM Ventas.Cliente c JOIN Personas.Persona p ON p.PersonaID=c.ClienteID;

    -- Equipo por rol SC + CBB
    SELECT NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS AS NombreRol, SUM(Total) AS Total
    FROM (
        SELECT r.NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS AS NombreRol, COUNT(*) AS Total
        FROM RRHH.Empleado e
        JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=e.EmpleadoID
        JOIN RRHH.Rol r ON r.RolID=er.RolID
        WHERE e.Activo=1
        GROUP BY r.RolID, r.NombreRol
        UNION ALL
        SELECT r.NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS AS NombreRol, COUNT(*) AS Total
        FROM CBB_NODE.SalonBelleza_CBB.RRHH.Empleado e
        JOIN CBB_NODE.SalonBelleza_CBB.RRHH.EmpleadoRol er ON er.EmpleadoID=e.EmpleadoID
        JOIN CBB_NODE.SalonBelleza_CBB.RRHH.Rol r ON r.RolID=er.RolID
        WHERE e.Activo=1
        GROUP BY r.RolID, r.NombreRol
    ) t
    GROUP BY NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS
    ORDER BY NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS;

    -- Ingresos últimos 12 meses SC + CBB
    SELECT Anio, Mes, SUM(Ingresos) AS Ingresos, SUM(Ventas) AS Ventas
    FROM (
        SELECT YEAR(v.Fecha) AS Anio, MONTH(v.Fecha) AS Mes,
            ISNULL(SUM(pg.Monto),0) AS Ingresos, COUNT(DISTINCT v.VentaID) AS Ventas
        FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID
        WHERE v.Fecha>=DATEADD(MONTH,-12,GETDATE())
        GROUP BY YEAR(v.Fecha),MONTH(v.Fecha)
        UNION ALL
        SELECT YEAR(v.Fecha) AS Anio, MONTH(v.Fecha) AS Mes,
            ISNULL(SUM(pg.Monto),0) AS Ingresos, COUNT(DISTINCT v.VentaID) AS Ventas
        FROM CBB_NODE.SalonBelleza_CBB.Ventas.Venta v
        JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Pago pg ON pg.VentaID=v.VentaID
        WHERE v.Fecha>=DATEADD(MONTH,-12,GETDATE())
        GROUP BY YEAR(v.Fecha),MONTH(v.Fecha)
    ) t
    GROUP BY Anio, Mes ORDER BY Anio ASC, Mes ASC;

    -- Nomina del mes SC + CBB
    SELECT
        ISNULL((SELECT SUM(SueldoBase) FROM RRHH.PagoNomina
                WHERE LEFT(Periodo,7)=LEFT(CONVERT(VARCHAR,GETDATE(),120),7)),0) +
        ISNULL((SELECT SUM(SueldoBase) FROM CBB_NODE.SalonBelleza_CBB.RRHH.PagoNomina
                WHERE LEFT(Periodo,7)=LEFT(CONVERT(VARCHAR,GETDATE(),120),7)),0) AS TotalSueldos,
        ISNULL((SELECT SUM(Comision) FROM RRHH.PagoNomina
                WHERE LEFT(Periodo,7)=LEFT(CONVERT(VARCHAR,GETDATE(),120),7)),0) +
        ISNULL((SELECT SUM(Comision) FROM CBB_NODE.SalonBelleza_CBB.RRHH.PagoNomina
                WHERE LEFT(Periodo,7)=LEFT(CONVERT(VARCHAR,GETDATE(),120),7)),0) AS TotalComisiones,
        ISNULL((SELECT SUM(SueldoBase+Comision) FROM RRHH.PagoNomina
                WHERE LEFT(Periodo,7)=LEFT(CONVERT(VARCHAR,GETDATE(),120),7)),0) +
        ISNULL((SELECT SUM(SueldoBase+Comision) FROM CBB_NODE.SalonBelleza_CBB.RRHH.PagoNomina
                WHERE LEFT(Periodo,7)=LEFT(CONVERT(VARCHAR,GETDATE(),120),7)),0) AS TotalNomina;

    -- Top 3 estilistas SC + CBB (un registro por empleado)
    SELECT TOP 3 Nombre, Apellido, NombreRol, TotalVentas, TotalIngresos
    FROM (
        SELECT
            p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS Nombre,
            p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS AS Apellido,
            MIN(r.NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS) AS NombreRol,
            COUNT(DISTINCT vds.VentaID) AS TotalVentas,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalIngresos
        FROM Ventas.VentaDetalleServicio vds
        JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
        JOIN Personas.Persona p ON p.PersonaID=vds.EmpleadoID
        JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=vds.EmpleadoID
        JOIN RRHH.Rol r ON r.RolID=er.RolID
        WHERE MONTH(v.Fecha)=MONTH(GETDATE()) AND YEAR(v.Fecha)=YEAR(GETDATE()) AND vds.EmpleadoID IS NOT NULL
        GROUP BY vds.EmpleadoID, p.Nombre, p.Apellido

        UNION ALL

        SELECT
            p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS Nombre,
            p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS AS Apellido,
            MIN(r.NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS) AS NombreRol,
            COUNT(DISTINCT vds.VentaID) AS TotalVentas,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalIngresos
        FROM CBB_NODE.SalonBelleza_CBB.Ventas.VentaDetalleServicio vds
        JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Venta v ON v.VentaID=vds.VentaID
        JOIN CBB_NODE.SalonBelleza_CBB.Personas.Persona p ON p.PersonaID=vds.EmpleadoID
        JOIN CBB_NODE.SalonBelleza_CBB.RRHH.EmpleadoRol er ON er.EmpleadoID=vds.EmpleadoID
        JOIN CBB_NODE.SalonBelleza_CBB.RRHH.Rol r ON r.RolID=er.RolID
        WHERE MONTH(v.Fecha)=MONTH(GETDATE()) AND YEAR(v.Fecha)=YEAR(GETDATE()) AND vds.EmpleadoID IS NOT NULL
        GROUP BY vds.EmpleadoID, p.Nombre, p.Apellido
    ) t
    ORDER BY TotalIngresos DESC;
END;
GO

-- 2. Reporte anual
--    RS[0] Ingresos por mes  RS[1] Nómina por mes  RS[2] Totales
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Duena.SP_ReporteAnual
    @Anio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AnioFiltro INT = ISNULL(@Anio, YEAR(GETDATE()));

    -- RS[0] Ingresos por mes SC + CBB
    SELECT Anio, Mes, SUM(Ingresos) AS Ingresos, SUM(Ventas) AS Ventas,
        SUM(TicketPromedio) AS TicketPromedio
    FROM (
        SELECT YEAR(v.Fecha) AS Anio, MONTH(v.Fecha) AS Mes,
            ISNULL(SUM(pg.Monto),0) AS Ingresos,
            COUNT(DISTINCT v.VentaID) AS Ventas,
            ISNULL(AVG(pg.Monto),0) AS TicketPromedio
        FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID
        WHERE YEAR(v.Fecha)=@AnioFiltro
        GROUP BY YEAR(v.Fecha),MONTH(v.Fecha)

        UNION ALL

        SELECT YEAR(v.Fecha) AS Anio, MONTH(v.Fecha) AS Mes,
            ISNULL(SUM(pg.Monto),0) AS Ingresos,
            COUNT(DISTINCT v.VentaID) AS Ventas,
            ISNULL(AVG(pg.Monto),0) AS TicketPromedio
        FROM CBB_NODE.SalonBelleza_CBB.Ventas.Venta v
        JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Pago pg ON pg.VentaID=v.VentaID
        WHERE YEAR(v.Fecha)=@AnioFiltro
        GROUP BY YEAR(v.Fecha),MONTH(v.Fecha)
    ) t
    GROUP BY Anio, Mes ORDER BY Mes ASC;

    -- RS[1] Nomina por mes SC + CBB
    SELECT Mes, SUM(TotalSueldos) AS TotalSueldos,
        SUM(TotalComisiones) AS TotalComisiones,
        SUM(TotalNomina) AS TotalNomina
    FROM (
        SELECT CAST(RIGHT(pn.Periodo,2) AS INT) AS Mes,
            SUM(pn.SueldoBase) AS TotalSueldos,
            SUM(pn.Comision) AS TotalComisiones,
            SUM(pn.SueldoBase+pn.Comision) AS TotalNomina
        FROM RRHH.PagoNomina pn
        WHERE LEFT(pn.Periodo,4)=CAST(@AnioFiltro AS VARCHAR)
        GROUP BY RIGHT(pn.Periodo,2)

        UNION ALL

        SELECT CAST(RIGHT(pn.Periodo,2) AS INT) AS Mes,
            SUM(pn.SueldoBase) AS TotalSueldos,
            SUM(pn.Comision) AS TotalComisiones,
            SUM(pn.SueldoBase+pn.Comision) AS TotalNomina
        FROM CBB_NODE.SalonBelleza_CBB.RRHH.PagoNomina pn
        WHERE LEFT(pn.Periodo,4)=CAST(@AnioFiltro AS VARCHAR)
        GROUP BY RIGHT(pn.Periodo,2)
    ) t
    GROUP BY Mes ORDER BY Mes ASC;

    -- RS[2] Totales globales
    SELECT
        ISNULL(SUM(pg.Monto),0) +
        ISNULL((SELECT SUM(pg2.Monto) FROM CBB_NODE.SalonBelleza_CBB.Ventas.Venta v2
                JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Pago pg2 ON pg2.VentaID=v2.VentaID
                WHERE YEAR(v2.Fecha)=@AnioFiltro),0) AS TotalIngresos,

        COUNT(DISTINCT v.VentaID) +
        ISNULL((SELECT COUNT(DISTINCT v2.VentaID) FROM CBB_NODE.SalonBelleza_CBB.Ventas.Venta v2
                WHERE YEAR(v2.Fecha)=@AnioFiltro),0) AS TotalVentas,

        ISNULL(AVG(pg.Monto),0) AS TicketPromedio
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID
    WHERE YEAR(v.Fecha)=@AnioFiltro;
END;
GO

-- 3. Ver todos los sueldos (nómina completa)
--    Sin duplicados por rol; comisiones desde VentaDetalleServicio
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Duena.SP_VerTodosLosSueldos
    @Anio INT = NULL,
    @Mes  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AnioFiltro INT = ISNULL(@Anio, YEAR(GETDATE()));
    DECLARE @MesFiltro  INT = ISNULL(@Mes,  MONTH(GETDATE()));
    DECLARE @Periodo    VARCHAR(7) = CAST(@AnioFiltro AS VARCHAR)+'-'+RIGHT('0'+CAST(@MesFiltro AS VARCHAR),2);

    SELECT EmpleadoID, Nombre, Apellido, Sucursal,
        SueldoBase, PorcentajeComision, TotalVentas, TotalComision, TotalNomina,
        YaPagado, FechaPago, MontoPagado, Periodo, PagadoPorDuena
    FROM (
        SELECT e.EmpleadoID,
            p.Nombre    COLLATE SQL_Latin1_General_CP1_CI_AS AS Nombre,
            p.Apellido  COLLATE SQL_Latin1_General_CP1_CI_AS AS Apellido,
            'Santa Cruz' COLLATE SQL_Latin1_General_CP1_CI_AS AS Sucursal,
            ISNULL(es.SueldoBase,0) AS SueldoBase,
            ISNULL(ec.Porcentaje,0) AS PorcentajeComision,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalVentas,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS TotalComision,
            ISNULL(es.SueldoBase,0)+ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS TotalNomina,
            CASE WHEN pn.PagoNominaID IS NOT NULL THEN 1 ELSE 0 END AS YaPagado,
            pn.FechaPago, pn.Total AS MontoPagado,
            @Periodo COLLATE SQL_Latin1_General_CP1_CI_AS AS Periodo,
            CASE WHEN EXISTS (SELECT 1 FROM RRHH.EmpleadoRol WHERE EmpleadoID=e.EmpleadoID AND RolID=2) THEN 1 ELSE 0 END AS PagadoPorDuena
        FROM RRHH.Empleado e
        JOIN Personas.Persona p ON p.PersonaID=e.EmpleadoID
        LEFT JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID=e.EmpleadoID AND es.FechaFin IS NULL
        LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=e.EmpleadoID AND ec.FechaFin IS NULL
        LEFT JOIN Ventas.VentaDetalleServicio vds ON vds.EmpleadoID=e.EmpleadoID
            AND EXISTS (SELECT 1 FROM Ventas.Venta v WHERE v.VentaID=vds.VentaID
                        AND MONTH(v.Fecha)=@MesFiltro AND YEAR(v.Fecha)=@AnioFiltro)
        LEFT JOIN RRHH.PagoNomina pn ON pn.EmpleadoID=e.EmpleadoID AND pn.Periodo=@Periodo
        WHERE e.Activo=1 AND EXISTS (SELECT 1 FROM RRHH.EmpleadoRol WHERE EmpleadoID=e.EmpleadoID AND RolID IN (2,3,4,5,6,7))
        GROUP BY e.EmpleadoID,p.Nombre,p.Apellido,es.SueldoBase,ec.Porcentaje,pn.PagoNominaID,pn.FechaPago,pn.Total

        UNION ALL

        SELECT e.EmpleadoID,
            p.Nombre    COLLATE SQL_Latin1_General_CP1_CI_AS AS Nombre,
            p.Apellido  COLLATE SQL_Latin1_General_CP1_CI_AS AS Apellido,
            'Cochabamba' COLLATE SQL_Latin1_General_CP1_CI_AS AS Sucursal,
            ISNULL(es.SueldoBase,0) AS SueldoBase,
            ISNULL(ec.Porcentaje,0) AS PorcentajeComision,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalVentas,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS TotalComision,
            ISNULL(es.SueldoBase,0)+ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS TotalNomina,
            CASE WHEN pn.PagoNominaID IS NOT NULL THEN 1 ELSE 0 END AS YaPagado,
            pn.FechaPago, pn.Total AS MontoPagado,
            @Periodo COLLATE SQL_Latin1_General_CP1_CI_AS AS Periodo,
            CASE WHEN EXISTS (SELECT 1 FROM CBB_NODE.SalonBelleza_CBB.RRHH.EmpleadoRol WHERE EmpleadoID=e.EmpleadoID AND RolID=2) THEN 1 ELSE 0 END AS PagadoPorDuena
        FROM CBB_NODE.SalonBelleza_CBB.RRHH.Empleado e
        JOIN CBB_NODE.SalonBelleza_CBB.Personas.Persona p ON p.PersonaID=e.EmpleadoID
        LEFT JOIN CBB_NODE.SalonBelleza_CBB.RRHH.EmpleadoSueldo es ON es.EmpleadoID=e.EmpleadoID AND es.FechaFin IS NULL
        LEFT JOIN CBB_NODE.SalonBelleza_CBB.RRHH.EmpleadoComision ec ON ec.EmpleadoID=e.EmpleadoID AND ec.FechaFin IS NULL
        LEFT JOIN CBB_NODE.SalonBelleza_CBB.Ventas.VentaDetalleServicio vds ON vds.EmpleadoID=e.EmpleadoID
            AND EXISTS (SELECT 1 FROM CBB_NODE.SalonBelleza_CBB.Ventas.Venta v WHERE v.VentaID=vds.VentaID
                        AND MONTH(v.Fecha)=@MesFiltro AND YEAR(v.Fecha)=@AnioFiltro)
        LEFT JOIN CBB_NODE.SalonBelleza_CBB.RRHH.PagoNomina pn ON pn.EmpleadoID=e.EmpleadoID AND pn.Periodo=@Periodo
        WHERE e.Activo=1 AND EXISTS (SELECT 1 FROM CBB_NODE.SalonBelleza_CBB.RRHH.EmpleadoRol WHERE EmpleadoID=e.EmpleadoID AND RolID IN (2,3,4,5,6,7))
        GROUP BY e.EmpleadoID,p.Nombre,p.Apellido,es.SueldoBase,ec.Porcentaje,pn.PagoNominaID,pn.FechaPago,pn.Total
    ) t
    ORDER BY Sucursal, Nombre;
END;
GO

-- 4. Registrar pago nómina del administrador
CREATE OR ALTER PROCEDURE RRHH.SP_RegistrarPagoNominaDuena
    @EmpleadoID  INT,
    @Periodo     VARCHAR(7),
    @MontoPagado DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM RRHH.EmpleadoRol WHERE EmpleadoID = @EmpleadoID AND RolID = 2)
        BEGIN ROLLBACK; RAISERROR('Solo puedes pagar al Administrador.', 16, 1); RETURN; END

        IF EXISTS (SELECT 1 FROM RRHH.PagoNomina WHERE EmpleadoID = @EmpleadoID AND Periodo = @Periodo)
        BEGIN ROLLBACK; RAISERROR('Este período ya fue pagado.', 16, 1); RETURN; END

        DECLARE @SueldoBase DECIMAL(10,2);
        SELECT @SueldoBase = ISNULL(SueldoBase, 0) FROM RRHH.EmpleadoSueldo
        WHERE EmpleadoID = @EmpleadoID AND FechaFin IS NULL;

        INSERT INTO RRHH.PagoNomina (EmpleadoID,Periodo,SueldoBase,Comision,FechaPago,Pagado)
        VALUES (@EmpleadoID,@Periodo,@SueldoBase,0,GETDATE(),1);
        COMMIT;
        SELECT 'Pago del Administrador registrado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al registrar el pago.', 16, 1);
    END CATCH
END;
GO

-- 5. Registrar administrador
CREATE OR ALTER PROCEDURE Duena.SP_RegistrarAdmin
    @Nombre        VARCHAR(100),
    @Apellido      VARCHAR(100),
    @Telefono      VARCHAR(20),
    @Email         VARCHAR(100),
    @PassHash      VARCHAR(255),
    @FechaContrato DATE,
    @SueldoBase    DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email = @Email)
        BEGIN ROLLBACK; RAISERROR('Este correo ya está registrado.', 16, 1); RETURN; END

        DECLARE @PersonaID INT;
        INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email) VALUES (@Nombre,@Apellido,@Telefono,@Email);
        SET @PersonaID = SCOPE_IDENTITY();

        INSERT INTO RRHH.Empleado (EmpleadoID,FechaContratacion,Activo) VALUES (@PersonaID,@FechaContrato,1);
        INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID) VALUES (@PersonaID,2);
        INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@PersonaID,@SueldoBase,@FechaContrato);
        INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@PersonaID,0.00,@FechaContrato);

        DECLARE @UsuarioID INT;
        INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@PersonaID,@Email,@PassHash);
        SET @UsuarioID = SCOPE_IDENTITY();
        INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UsuarioID,2);

        COMMIT;
        SELECT @PersonaID AS EmpleadoID, 'Administrador registrado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @Error VARCHAR(500) = ERROR_MESSAGE();
        RAISERROR(@Error,16,1);
    END CATCH
END;
GO

-- 6. Perfil de la dueña
CREATE OR ALTER PROCEDURE Duena.SP_ObtenerPerfil
    @PersonaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PersonaID, p.Nombre, p.Apellido, p.Email, p.Telefono,
           p.FechaNacimiento, r.Nombre AS NombreRol
    FROM Personas.Persona      p
    JOIN Seguridad.Usuario      u  ON u.PersonaID  = p.PersonaID
    JOIN Seguridad.UsuarioRol   ur ON ur.UsuarioID = u.UsuarioID
    JOIN Seguridad.Rol          r  ON r.RolID      = ur.RolID
    WHERE p.PersonaID = @PersonaID;
END;
GO

-- 7. Activar / desactivar empleado
CREATE OR ALTER PROCEDURE Duena.SP_CambiarEstadoEmpleado
    @EmpleadoID INT,
    @Activo     BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE RRHH.Empleado    SET Activo = @Activo WHERE EmpleadoID = @EmpleadoID;
    UPDATE Seguridad.Usuario SET Activo = @Activo WHERE PersonaID  = @EmpleadoID;
    SELECT 'Estado actualizado correctamente.' AS Mensaje;
END;
GO

-- 8. Proveedores
CREATE OR ALTER PROCEDURE Inventario.SP_ListarProveedores
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ProveedorID, Nombre, Telefono, Email, Activo FROM Inventario.Proveedor ORDER BY Nombre;
END;
GO

CREATE OR ALTER PROCEDURE Inventario.SP_CrearProveedor
    @Nombre   VARCHAR(100),
    @Telefono VARCHAR(20)  = NULL,
    @Email    VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Inventario.Proveedor (Nombre,Telefono,Email) VALUES (@Nombre,@Telefono,@Email);
    SELECT SCOPE_IDENTITY() AS ProveedorID, 'Proveedor creado.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE Inventario.SP_EditarProveedor
    @ProveedorID INT,
    @Nombre      VARCHAR(100),
    @Telefono    VARCHAR(20)  = NULL,
    @Email       VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Inventario.Proveedor SET Nombre=@Nombre, Telefono=@Telefono, Email=@Email
    WHERE ProveedorID = @ProveedorID;
    SELECT 'Proveedor actualizado.' AS Mensaje;
END;
GO

-- 9. Productos
CREATE OR ALTER PROCEDURE Inventario.SP_CrearProducto
    @Nombre       VARCHAR(100),
    @StockActual  INT           = 0,
    @StockMinimo  INT           = 5,
    @UnidadMedida VARCHAR(20)   = NULL,
    @Precio       DECIMAL(10,2),
    @ProveedorID  INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @ProductoID INT;
        INSERT INTO Inventario.Producto (Nombre,StockActual,StockMinimo,UnidadMedida,Activo)
        VALUES (@Nombre,@StockActual,@StockMinimo,@UnidadMedida,1);
        SET @ProductoID = SCOPE_IDENTITY();

        INSERT INTO Inventario.ProductoPrecio (ProductoID,Precio,FechaInicio) VALUES (@ProductoID,@Precio,GETDATE());

        IF @ProveedorID IS NOT NULL
            INSERT INTO Inventario.ProductoProveedor (ProductoID,ProveedorID) VALUES (@ProductoID,@ProveedorID);

        IF @StockActual > 0
            INSERT INTO Inventario.MovimientoInventario (ProductoID,EsEntrada,Cantidad,Fecha)
            VALUES (@ProductoID,1,@StockActual,GETDATE());

        COMMIT;
        SELECT @ProductoID AS ProductoID, 'Producto creado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al crear el producto.', 16, 1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Inventario.SP_EditarProducto
    @ProductoID   INT,
    @Nombre       VARCHAR(100),
    @StockMinimo  INT,
    @UnidadMedida VARCHAR(20)   = NULL,
    @NuevoPrecio  DECIMAL(10,2) = NULL,
    @ProveedorID  INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Inventario.Producto SET Nombre=@Nombre, StockMinimo=@StockMinimo, UnidadMedida=@UnidadMedida
        WHERE ProductoID = @ProductoID;

        DELETE FROM Inventario.ProductoProveedor WHERE ProductoID = @ProductoID;
        IF @ProveedorID IS NOT NULL
            INSERT INTO Inventario.ProductoProveedor (ProductoID,ProveedorID) VALUES (@ProductoID,@ProveedorID);

        IF @NuevoPrecio IS NOT NULL
        BEGIN
            UPDATE Inventario.ProductoPrecio SET FechaFin = GETDATE() WHERE ProductoID = @ProductoID AND FechaFin IS NULL;
            INSERT INTO Inventario.ProductoPrecio (ProductoID,Precio,FechaInicio) VALUES (@ProductoID,@NuevoPrecio,GETDATE());
        END
        COMMIT;
        SELECT 'Producto actualizado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al editar el producto.', 16, 1);
    END CATCH
END;
GO

-- 10. Servicios
CREATE OR ALTER PROCEDURE Servicios.SP_CrearServicio
    @Nombre         VARCHAR(100),
    @Descripcion    VARCHAR(300) = NULL,
    @DuracionMin    INT,
    @SubcategoriaID INT,
    @Precio         DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @ServicioID INT;
        INSERT INTO Servicios.Servicio (Nombre,Descripcion,DuracionMin,SubcategoriaID,Activo)
        VALUES (@Nombre,@Descripcion,@DuracionMin,@SubcategoriaID,1);
        SET @ServicioID = SCOPE_IDENTITY();
        INSERT INTO Servicios.ServicioPrecio (ServicioID,Precio,FechaInicio) VALUES (@ServicioID,@Precio,GETDATE());
        COMMIT;
        SELECT @ServicioID AS ServicioID, 'Servicio creado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al crear el servicio.', 16, 1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Servicios.SP_EditarServicio
    @ServicioID  INT,
    @Nombre      VARCHAR(100),
    @Descripcion VARCHAR(300) = NULL,
    @DuracionMin INT,
    @Activo      BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Servicios.Servicio SET Nombre=@Nombre, Descripcion=@Descripcion,
           DuracionMin=@DuracionMin, Activo=@Activo WHERE ServicioID = @ServicioID;
    SELECT 'Servicio actualizado.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE Servicios.SP_ListarSubcategorias
AS
BEGIN
    SET NOCOUNT ON;
    SELECT sc.SubcategoriaID, sc.Nombre, cat.Nombre AS Categoria, cat.CategoriaID
    FROM Servicios.SubcategoriaServicio sc
    JOIN Servicios.CategoriaServicio    cat ON cat.CategoriaID = sc.CategoriaID
    ORDER BY cat.Nombre, sc.Nombre;
END;
GO

-- 11. Editar promoción
CREATE OR ALTER PROCEDURE Marketing.SP_EditarPromocion
    @PromocionID INT,
    @Nombre      VARCHAR(100),
    @Descripcion VARCHAR(300) = NULL,
    @Descuento   DECIMAL(5,2),
    @FechaInicio DATE,
    @FechaFin    DATE,
    @Activo      BIT          = 1,
    @ServicioIDs VARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Marketing.Promocion
        SET Nombre=@Nombre, Descripcion=@Descripcion, Descuento=@Descuento,
            FechaInicio=@FechaInicio, FechaFin=@FechaFin, Activo=@Activo
        WHERE PromocionID = @PromocionID;

        IF @ServicioIDs IS NOT NULL
        BEGIN
            DELETE FROM Marketing.PromocionServicio WHERE PromocionID = @PromocionID;
            INSERT INTO Marketing.PromocionServicio (PromocionID,ServicioID)
            SELECT @PromocionID, CAST(value AS INT) FROM STRING_SPLIT(@ServicioIDs,',')
            WHERE LTRIM(RTRIM(value)) <> '';
        END
        COMMIT;
        SELECT 'Promoción actualizada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar promoción.', 16, 1);
    END CATCH
END;
GO

-- 12. Listar empleados
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Duena.SP_ListarEmpleados
AS
BEGIN
    SET NOCOUNT ON;

    SELECT e.EmpleadoID,
        p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS Nombre,
        p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS AS Apellido,
        p.Email COLLATE SQL_Latin1_General_CP1_CI_AS AS Email,
        p.Telefono COLLATE SQL_Latin1_General_CP1_CI_AS AS Telefono,
        p.FechaNacimiento, p.Activo AS PersonaActiva,
        STRING_AGG(r.NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS,', ')
            WITHIN GROUP (ORDER BY r.RolID) AS Roles,
        STRING_AGG(CAST(r.RolID AS VARCHAR),',')
            WITHIN GROUP (ORDER BY r.RolID) AS RoleIDs,
        MIN(r.RolID) AS RolID,
        MIN(r.NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS) AS NombreRol,
        e.FechaContratacion, e.Activo,
        ISNULL(es.SueldoBase,0) AS SueldoBase,
        ISNULL(ec.Porcentaje,0) AS PorcentajeComision,
        'Santa Cruz' COLLATE SQL_Latin1_General_CP1_CI_AS AS Sucursal
    FROM RRHH.Empleado e
    JOIN Personas.Persona p ON p.PersonaID=e.EmpleadoID
    JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=e.EmpleadoID
    JOIN RRHH.Rol r ON r.RolID=er.RolID
    LEFT JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID=e.EmpleadoID AND es.FechaFin IS NULL
    LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=e.EmpleadoID AND ec.FechaFin IS NULL
    GROUP BY e.EmpleadoID,p.Nombre,p.Apellido,p.Email,p.Telefono,
        p.FechaNacimiento,p.Activo,e.FechaContratacion,e.Activo,es.SueldoBase,ec.Porcentaje

    UNION ALL

    SELECT e.EmpleadoID,
        p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS Nombre,
        p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS AS Apellido,
        p.Email COLLATE SQL_Latin1_General_CP1_CI_AS AS Email,
        p.Telefono COLLATE SQL_Latin1_General_CP1_CI_AS AS Telefono,
        p.FechaNacimiento, p.Activo AS PersonaActiva,
        STRING_AGG(r.NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS,', ')
            WITHIN GROUP (ORDER BY r.RolID) AS Roles,
        STRING_AGG(CAST(r.RolID AS VARCHAR),',')
            WITHIN GROUP (ORDER BY r.RolID) AS RoleIDs,
        MIN(r.RolID) AS RolID,
        MIN(r.NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS) AS NombreRol,
        e.FechaContratacion, e.Activo,
        ISNULL(es.SueldoBase,0) AS SueldoBase,
        ISNULL(ec.Porcentaje,0) AS PorcentajeComision,
        'Cochabamba' COLLATE SQL_Latin1_General_CP1_CI_AS AS Sucursal
    FROM CBB_NODE.SalonBelleza_CBB.RRHH.Empleado e
    JOIN CBB_NODE.SalonBelleza_CBB.Personas.Persona p ON p.PersonaID=e.EmpleadoID
    JOIN CBB_NODE.SalonBelleza_CBB.RRHH.EmpleadoRol er ON er.EmpleadoID=e.EmpleadoID
    JOIN CBB_NODE.SalonBelleza_CBB.RRHH.Rol r ON r.RolID=er.RolID
    LEFT JOIN CBB_NODE.SalonBelleza_CBB.RRHH.EmpleadoSueldo es ON es.EmpleadoID=e.EmpleadoID AND es.FechaFin IS NULL
    LEFT JOIN CBB_NODE.SalonBelleza_CBB.RRHH.EmpleadoComision ec ON ec.EmpleadoID=e.EmpleadoID AND ec.FechaFin IS NULL
    GROUP BY e.EmpleadoID,p.Nombre,p.Apellido,p.Email,p.Telefono,
        p.FechaNacimiento,p.Activo,e.FechaContratacion,e.Activo,es.SueldoBase,ec.Porcentaje

    ORDER BY Sucursal, NombreRol, Nombre;
END;
GO

-- 13. Reporte Ventas
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Duena.SP_ReporteVentas
    @FechaInicio DATE = NULL,
    @FechaFin    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Por empleado SC + CBB (solo personal técnico)
    SELECT Nombre, Apellido, NombreRol, TotalVentas, TotalIngresos, TotalComision
    FROM (
        SELECT
            p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS Nombre,
            p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS AS Apellido,
            MIN(r.NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS) AS NombreRol,
            COUNT(DISTINCT vds.VentaID) AS TotalVentas,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalIngresos,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS TotalComision
        FROM Ventas.VentaDetalleServicio vds
        JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
        JOIN Personas.Persona p ON p.PersonaID=vds.EmpleadoID
        JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=vds.EmpleadoID
        JOIN RRHH.Rol r ON r.RolID=er.RolID
        LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=vds.EmpleadoID AND ec.FechaFin IS NULL
        WHERE (@FechaInicio IS NULL OR CAST(v.Fecha AS DATE)>=@FechaInicio)
          AND (@FechaFin IS NULL OR CAST(v.Fecha AS DATE)<=@FechaFin)
          AND vds.EmpleadoID IS NOT NULL
          AND er.RolID IN (3,4,5,6)
        GROUP BY vds.EmpleadoID, p.Nombre, p.Apellido

        UNION ALL

        SELECT
            p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS Nombre,
            p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS AS Apellido,
            MIN(r.NombreRol COLLATE SQL_Latin1_General_CP1_CI_AS) AS NombreRol,
            COUNT(DISTINCT vds.VentaID) AS TotalVentas,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalIngresos,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS TotalComision
        FROM CBB_NODE.SalonBelleza_CBB.Ventas.VentaDetalleServicio vds
        JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Venta v ON v.VentaID=vds.VentaID
        JOIN CBB_NODE.SalonBelleza_CBB.Personas.Persona p ON p.PersonaID=vds.EmpleadoID
        JOIN CBB_NODE.SalonBelleza_CBB.RRHH.EmpleadoRol er ON er.EmpleadoID=vds.EmpleadoID
        JOIN CBB_NODE.SalonBelleza_CBB.RRHH.Rol r ON r.RolID=er.RolID
        LEFT JOIN CBB_NODE.SalonBelleza_CBB.RRHH.EmpleadoComision ec ON ec.EmpleadoID=vds.EmpleadoID AND ec.FechaFin IS NULL
        WHERE (@FechaInicio IS NULL OR CAST(v.Fecha AS DATE)>=@FechaInicio)
          AND (@FechaFin IS NULL OR CAST(v.Fecha AS DATE)<=@FechaFin)
          AND vds.EmpleadoID IS NOT NULL
          AND er.RolID IN (3,4,5,6)
        GROUP BY vds.EmpleadoID, p.Nombre, p.Apellido
    ) t
    ORDER BY TotalIngresos DESC;

    -- Por servicio SC + CBB Top 10
    SELECT TOP 10 Servicio, SUM(TotalVeces) AS TotalVeces, SUM(TotalIngresos) AS TotalIngresos
    FROM (
        SELECT
            s.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS Servicio,
            SUM(vds.Cantidad) AS TotalVeces,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalIngresos
        FROM Ventas.VentaDetalleServicio vds
        JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
        JOIN Servicios.Servicio s ON s.ServicioID=vds.ServicioID
        WHERE (@FechaInicio IS NULL OR CAST(v.Fecha AS DATE)>=@FechaInicio)
          AND (@FechaFin IS NULL OR CAST(v.Fecha AS DATE)<=@FechaFin)
        GROUP BY vds.ServicioID, s.Nombre

        UNION ALL

        SELECT
            s.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS Servicio,
            SUM(vds.Cantidad) AS TotalVeces,
            ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalIngresos
        FROM CBB_NODE.SalonBelleza_CBB.Ventas.VentaDetalleServicio vds
        JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Venta v ON v.VentaID=vds.VentaID
        JOIN CBB_NODE.SalonBelleza_CBB.Servicios.Servicio s ON s.ServicioID=vds.ServicioID
        WHERE (@FechaInicio IS NULL OR CAST(v.Fecha AS DATE)>=@FechaInicio)
          AND (@FechaFin IS NULL OR CAST(v.Fecha AS DATE)<=@FechaFin)
        GROUP BY vds.ServicioID, s.Nombre
    ) t
    GROUP BY Servicio
    ORDER BY TotalIngresos DESC;

    -- Totales
    SELECT
        ISNULL(SUM(pg.Monto),0) +
        ISNULL((SELECT SUM(pg2.Monto) FROM CBB_NODE.SalonBelleza_CBB.Ventas.Venta v2
                JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Pago pg2 ON pg2.VentaID=v2.VentaID
                WHERE (@FechaInicio IS NULL OR CAST(v2.Fecha AS DATE)>=@FechaInicio)
                  AND (@FechaFin IS NULL OR CAST(v2.Fecha AS DATE)<=@FechaFin)),0) AS TotalIngresos,
        COUNT(DISTINCT v.VentaID) +
        ISNULL((SELECT COUNT(DISTINCT v2.VentaID) FROM CBB_NODE.SalonBelleza_CBB.Ventas.Venta v2
                WHERE (@FechaInicio IS NULL OR CAST(v2.Fecha AS DATE)>=@FechaInicio)
                  AND (@FechaFin IS NULL OR CAST(v2.Fecha AS DATE)<=@FechaFin)),0) AS TotalVentas,
        ISNULL(AVG(pg.Monto),0) AS TicketPromedio
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID
    WHERE (@FechaInicio IS NULL OR CAST(v.Fecha AS DATE)>=@FechaInicio)
      AND (@FechaFin IS NULL OR CAST(v.Fecha AS DATE)<=@FechaFin);
END;
GO

-- 14. Listar clientes
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Duena.SP_ListarClientes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.PersonaID,
        p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS Nombre,
        p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS AS Apellido,
        p.Email COLLATE SQL_Latin1_General_CP1_CI_AS AS Email,
        p.Telefono COLLATE SQL_Latin1_General_CP1_CI_AS AS Telefono,
        p.FechaNacimiento,
        'Santa Cruz' COLLATE SQL_Latin1_General_CP1_CI_AS AS Sucursal
    FROM Ventas.Cliente c
    JOIN Personas.Persona p ON p.PersonaID = c.ClienteID

    UNION ALL

    SELECT 
        p.PersonaID,
        p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS,
        p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS,
        p.Email COLLATE SQL_Latin1_General_CP1_CI_AS,
        p.Telefono COLLATE SQL_Latin1_General_CP1_CI_AS,
        p.FechaNacimiento,
        'Cochabamba' COLLATE SQL_Latin1_General_CP1_CI_AS
    FROM CBB_NODE.SalonBelleza_CBB.Ventas.Cliente c
    JOIN CBB_NODE.SalonBelleza_CBB.Personas.Persona p ON p.PersonaID = c.ClienteID

    ORDER BY Sucursal, Apellido, Nombre;
END;
GO

-- 15. Listar citas del día
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Duena.SP_CitasDelDia
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        c.CitaID,
        p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS NombreCliente,
        p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS AS ApellidoCliente,
        s.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS Servicio,
        pe.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS NombreEmpleado,
        pe.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS AS ApellidoEmpleado,
        c.FechaInicio,
        est.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS Estado,
        'Santa Cruz' COLLATE SQL_Latin1_General_CP1_CI_AS AS Sucursal
    FROM Agenda.Cita c
    JOIN Ventas.Cliente cl ON cl.ClienteID = c.ClienteID
    JOIN Personas.Persona p ON p.PersonaID = cl.ClienteID
    JOIN Agenda.CitaServicio cs ON cs.CitaID = c.CitaID
    JOIN Servicios.Servicio s ON s.ServicioID = cs.ServicioID
    LEFT JOIN Agenda.CitaEmpleado ce ON ce.CitaID = c.CitaID
    LEFT JOIN Personas.Persona pe ON pe.PersonaID = ce.EmpleadoID
    JOIN Agenda.EstadoCita est ON est.EstadoID = c.EstadoID
    WHERE CAST(c.FechaInicio AS DATE) = CAST(GETDATE() AS DATE)

    UNION ALL

    SELECT 
        c.CitaID,
        p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS,
        p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS,
        s.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS,
        pe.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS,
        pe.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS,
        c.FechaInicio,
        est.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS,
        'Cochabamba' COLLATE SQL_Latin1_General_CP1_CI_AS
    FROM CBB_NODE.SalonBelleza_CBB.Agenda.Cita c
    JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Cliente cl ON cl.ClienteID = c.ClienteID
    JOIN CBB_NODE.SalonBelleza_CBB.Personas.Persona p ON p.PersonaID = cl.ClienteID
    JOIN CBB_NODE.SalonBelleza_CBB.Agenda.CitaServicio cs ON cs.CitaID = c.CitaID
    JOIN CBB_NODE.SalonBelleza_CBB.Servicios.Servicio s ON s.ServicioID = cs.ServicioID
    LEFT JOIN CBB_NODE.SalonBelleza_CBB.Agenda.CitaEmpleado ce ON ce.CitaID = c.CitaID
    LEFT JOIN CBB_NODE.SalonBelleza_CBB.Personas.Persona pe ON pe.PersonaID = ce.EmpleadoID
    JOIN CBB_NODE.SalonBelleza_CBB.Agenda.EstadoCita est ON est.EstadoID = c.EstadoID
    WHERE CAST(c.FechaInicio AS DATE) = CAST(GETDATE() AS DATE)

    ORDER BY Sucursal, FechaInicio;
END;
GO

-- 16. Facturas consolidadas
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Duena.SP_ListarFacturas
    @FechaInicio DATE = NULL,
    @FechaFin    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        f.FacturaID,
        f.NumeroFactura COLLATE SQL_Latin1_General_CP1_CI_AS AS NumeroFactura,
        p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS AS NombreCliente,
        p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS AS ApellidoCliente,
        f.Fecha,
        ISNULL(SUM(pg.Monto),0) AS Total,
        f.Estado COLLATE SQL_Latin1_General_CP1_CI_AS AS Estado,
        'Santa Cruz' COLLATE SQL_Latin1_General_CP1_CI_AS AS Sucursal
    FROM Facturacion.Factura f
    JOIN Ventas.Venta v ON v.VentaID = f.VentaID
    JOIN Ventas.Cliente cl ON cl.ClienteID = v.ClienteID
    JOIN Personas.Persona p ON p.PersonaID = cl.ClienteID
    LEFT JOIN Ventas.Pago pg ON pg.VentaID = v.VentaID
    WHERE (@FechaInicio IS NULL OR CAST(f.Fecha AS DATE) >= @FechaInicio)
      AND (@FechaFin IS NULL OR CAST(f.Fecha AS DATE) <= @FechaFin)
    GROUP BY f.FacturaID, f.NumeroFactura, p.Nombre, p.Apellido, f.Fecha, f.Estado

    UNION ALL

    SELECT
        f.FacturaID,
        f.NumeroFactura COLLATE SQL_Latin1_General_CP1_CI_AS,
        p.Nombre COLLATE SQL_Latin1_General_CP1_CI_AS,
        p.Apellido COLLATE SQL_Latin1_General_CP1_CI_AS,
        f.Fecha,
        ISNULL(SUM(pg.Monto),0) AS Total,
        f.Estado COLLATE SQL_Latin1_General_CP1_CI_AS,
        'Cochabamba' COLLATE SQL_Latin1_General_CP1_CI_AS
    FROM CBB_NODE.SalonBelleza_CBB.Facturacion.Factura f
    JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Venta v ON v.VentaID = f.VentaID
    JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Cliente cl ON cl.ClienteID = v.ClienteID
    JOIN CBB_NODE.SalonBelleza_CBB.Personas.Persona p ON p.PersonaID = cl.ClienteID
    LEFT JOIN CBB_NODE.SalonBelleza_CBB.Ventas.Pago pg ON pg.VentaID = v.VentaID
    WHERE (@FechaInicio IS NULL OR CAST(f.Fecha AS DATE) >= @FechaInicio)
      AND (@FechaFin IS NULL OR CAST(f.Fecha AS DATE) <= @FechaFin)
    GROUP BY f.FacturaID, f.NumeroFactura, p.Nombre, p.Apellido, f.Fecha, f.Estado

    ORDER BY Sucursal, Fecha DESC;
END;
GO