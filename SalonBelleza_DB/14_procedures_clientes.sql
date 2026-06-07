-- COCO Salón de Belleza · SalonBelleza_DB
-- 14 · STORED PROCEDURES · MÓDULO CLIENTES

USE SalonBelleza_DB;
GO

-- 1. Obtener citas del cliente
--    RS[0] Próximas citas  RS[1] Historial
--    Usa LEFT JOIN en empleado para soportar citas sin asignación
CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerCitasCliente
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Próximas citas
    SELECT
        c.CitaID, c.FechaInicio,
        cs.CitaServicioID, cs.ServicioID,
        s.Nombre          AS Servicio,
        s.DuracionMin,
        cs.FechaInicioServicio, cs.FechaFinServicio,
        cs.EsParalelo, cs.Orden,
        p.Nombre          AS Empleado,
        p.Apellido        AS EmpleadoApellido,
        ec.EstadoID, ec.Nombre AS Estado,
        sp.Precio
    FROM Agenda.Cita              c
    JOIN Agenda.CitaServicio      cs ON cs.CitaID     = c.CitaID
    JOIN Servicios.Servicio       s  ON s.ServicioID  = cs.ServicioID
    LEFT JOIN Personas.Persona    p  ON p.PersonaID   = cs.EmpleadoID
    JOIN Agenda.EstadoCita        ec ON ec.EstadoID   = c.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
    WHERE c.ClienteID = @ClienteID
      AND c.FechaInicio >= GETDATE()
      AND c.EstadoID NOT IN (12, 13)
    ORDER BY c.FechaInicio ASC, cs.Orden ASC;

    -- Historial
    SELECT
        c.CitaID, c.FechaInicio,
        cs.ServicioID,
        s.Nombre          AS Servicio,
        s.DuracionMin,
        cs.FechaInicioServicio, cs.FechaFinServicio,
        cs.EsParalelo, cs.Orden,
        p.Nombre          AS Empleado,
        p.Apellido        AS EmpleadoApellido,
        ec.EstadoID, ec.Nombre AS Estado,
        sp.Precio
    FROM Agenda.Cita              c
    JOIN Agenda.CitaServicio      cs ON cs.CitaID     = c.CitaID
    JOIN Servicios.Servicio       s  ON s.ServicioID  = cs.ServicioID
    LEFT JOIN Personas.Persona    p  ON p.PersonaID   = cs.EmpleadoID
    JOIN Agenda.EstadoCita        ec ON ec.EstadoID   = c.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
    WHERE c.ClienteID = @ClienteID
      AND (c.FechaInicio < GETDATE() OR c.EstadoID IN (11, 12, 13))
    ORDER BY c.FechaInicio DESC, cs.Orden ASC;
END;
GO

-- 2. Estadísticas del cliente (pantalla Inicio)
--    RS[0] Próxima cita  RS[1] Visitas año  RS[2] Total gastado
--    RS[3] Cantidad de promociones activas
CREATE OR ALTER PROCEDURE Agenda.SP_EstadisticasCliente
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        c.CitaID, c.FechaInicio,
        cs.ServicioID,
        s.Nombre  AS Servicio,
        p.Nombre  AS Estilista,
        ec.Nombre AS Estado
    FROM Agenda.Cita         c
    JOIN Agenda.CitaServicio cs ON cs.CitaID    = c.CitaID
    JOIN Servicios.Servicio  s  ON s.ServicioID = cs.ServicioID
    JOIN Agenda.CitaEmpleado ce ON ce.CitaID    = c.CitaID
    JOIN Personas.Persona    p  ON p.PersonaID  = ce.EmpleadoID
    JOIN Agenda.EstadoCita   ec ON ec.EstadoID  = c.EstadoID
    WHERE c.ClienteID  = @ClienteID
      AND c.FechaInicio >= GETDATE()
      AND c.EstadoID IN (8, 9)
    ORDER BY c.FechaInicio ASC;

    SELECT COUNT(DISTINCT v.VentaID) AS VisitasAnio
    FROM Ventas.Venta                v
    JOIN Ventas.VentaDetalleServicio vds ON vds.VentaID = v.VentaID
    WHERE v.ClienteID = @ClienteID
      AND YEAR(v.Fecha) = YEAR(GETDATE());

    SELECT ISNULL(SUM(pg.Monto), 0) AS TotalGastado
    FROM Ventas.Venta v
    JOIN Ventas.Pago  pg ON pg.VentaID = v.VentaID
    WHERE v.ClienteID = @ClienteID;

    SELECT
        (SELECT COUNT(*) FROM Marketing.Promocion
         WHERE Activo = 1
           AND ISNULL(TipoPromocion,'general') <> 'cumpleanos'
           AND FechaInicio <= CAST(GETDATE() AS DATE)
           AND FechaFin    >= CAST(GETDATE() AS DATE))
        +
        (SELECT COUNT(*) FROM Personas.Persona
         WHERE PersonaID = @ClienteID
           AND FechaNacimiento IS NOT NULL
           AND MONTH(FechaNacimiento) = MONTH(GETDATE())
           AND DAY(FechaNacimiento)   = DAY(GETDATE()))
        AS PromocionesActivas;
END;
GO

-- 3. Empleados disponibles para un servicio y horario
--    Excluye empleados con día libre aprobado (Estado='Aprobada')
--    Excluye empleados con cita en ese rango horario
CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerEmpleadosDisponibles
    @ServicioID  INT,
    @FechaInicio NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FechaInicioD DATETIME = CONVERT(DATETIME, REPLACE(@FechaInicio,'T',' '), 120);
    DECLARE @DuracionMin    INT;
    DECLARE @SubcategoriaID INT;

    SELECT @DuracionMin = DuracionMin, @SubcategoriaID = SubcategoriaID
    FROM Servicios.Servicio
    WHERE ServicioID = @ServicioID AND Activo = 1;

    IF @DuracionMin IS NULL
    BEGIN RAISERROR('Servicio no encontrado o inactivo', 16, 1); RETURN; END

    DECLARE @FechaFin      DATETIME = DATEADD(MINUTE, @DuracionMin, @FechaInicioD);
    DECLARE @DiaSemana     TINYINT  = DATEPART(WEEKDAY, @FechaInicioD);
    DECLARE @DiaConvertido TINYINT  = CASE @DiaSemana
        WHEN 1 THEN 7 WHEN 2 THEN 1 WHEN 3 THEN 2
        WHEN 4 THEN 3 WHEN 5 THEN 4 WHEN 6 THEN 5 WHEN 7 THEN 6
    END;
    DECLARE @HoraInicio TIME = CAST(@FechaInicioD AS TIME);
    DECLARE @HoraFin    TIME = CAST(@FechaFin    AS TIME);

    IF @DiaConvertido = 7 AND NOT EXISTS (
        SELECT 1 FROM RRHH.HorarioExcepcion
        WHERE Fecha = CAST(@FechaInicioD AS DATE) AND Disponible = 1 AND Aprobado = 1
    )
    BEGIN RAISERROR('El salón no atiende los domingos.', 16, 1); RETURN; END

    IF @HoraInicio < '09:00' OR @HoraFin > '19:00'
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM RRHH.HorarioExcepcion
            WHERE Fecha = CAST(@FechaInicioD AS DATE) AND Disponible = 1 AND Aprobado = 1
        )
        BEGIN RAISERROR('El horario debe ser entre 09:00 y 19:00.', 16, 1); RETURN; END
    END

    SELECT
        e.EmpleadoID, p.Nombre, p.Apellido, r.RolID, r.NombreRol
    FROM RRHH.Empleado            e
    JOIN Personas.Persona          p  ON p.PersonaID   = e.EmpleadoID
    JOIN RRHH.EmpleadoRol          er ON er.EmpleadoID = e.EmpleadoID
    JOIN RRHH.Rol                  r  ON r.RolID       = er.RolID
    JOIN Servicios.SubcategoriaRol sr ON sr.RolID      = er.RolID
    WHERE sr.SubcategoriaID = @SubcategoriaID
      AND e.Activo          = 1
      AND r.RolID           IN (3, 4, 5, 6)
      AND EXISTS (
          SELECT 1 FROM RRHH.HorarioEmpleado h
          WHERE h.EmpleadoID  = e.EmpleadoID
            AND h.DiaSemana   = @DiaConvertido
            AND h.HoraEntrada <= @HoraInicio
            AND h.HoraSalida  >= @HoraFin
            AND h.Activo      = 1
      )
      AND NOT EXISTS (
          SELECT 1 FROM RRHH.HorarioExcepcion ex
          WHERE ex.EmpleadoID = e.EmpleadoID
            AND ex.Fecha      = CAST(@FechaInicioD AS DATE)
            AND ex.Disponible = 0
            AND ex.Estado     = 'Aprobada'
      )
      AND e.EmpleadoID NOT IN (
          SELECT cs.EmpleadoID
          FROM Agenda.CitaServicio cs
          JOIN Agenda.Cita         c ON c.CitaID = cs.CitaID
          WHERE cs.EmpleadoID IS NOT NULL
            AND c.EstadoID NOT IN (12, 13)
            AND cs.FechaInicioServicio < @FechaFin
            AND cs.FechaFinServicio    > @FechaInicioD
      )
    ORDER BY p.Nombre;
END;
GO

-- 4. Slots ocupados por franja horaria
--    Devuelve hora y cantidad de empleados ocupados
--    Usado para colorear el selector de horarios en el wizard
CREATE OR ALTER PROCEDURE Agenda.SP_SlotsOcupados
    @Fecha       DATE,
    @ServicioIDs VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(cs.FechaInicioServicio AS TIME(0)) AS HoraInicio,
        COUNT(DISTINCT cs.EmpleadoID)           AS EmpleadosOcupados
    FROM Agenda.CitaServicio cs
    JOIN Agenda.Cita         c ON c.CitaID = cs.CitaID
    WHERE CAST(cs.FechaInicioServicio AS DATE) = @Fecha
      AND c.EstadoID NOT IN (12, 13)
      AND cs.EmpleadoID IS NOT NULL
    GROUP BY CAST(cs.FechaInicioServicio AS TIME(0))
    ORDER BY HoraInicio;
END;
GO

-- 5. Reservar cita (portal cliente)
--    Asigna empleado automáticamente si EmpleadoID = 0
--    Verifica: domingos · día libre · conflicto de horario · límite 19:00
CREATE OR ALTER PROCEDURE Agenda.SP_ReservarCita
    @ClienteID   INT,
    @FechaInicio NVARCHAR(30),
    @ServicioIDs VARCHAR(500),
    @EmpleadoIDs VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        DECLARE @FechaInicioD DATETIME = CONVERT(DATETIME, REPLACE(@FechaInicio, 'T', ' '), 120);
        DECLARE @DiaSemana     TINYINT = DATEPART(WEEKDAY, @FechaInicioD);
        DECLARE @DiaConvertido TINYINT = CASE @DiaSemana
            WHEN 1 THEN 7 WHEN 2 THEN 1 WHEN 3 THEN 2
            WHEN 4 THEN 3 WHEN 5 THEN 4 WHEN 6 THEN 5 WHEN 7 THEN 6
        END;

        IF @DiaConvertido = 7 AND NOT EXISTS (
            SELECT 1 FROM RRHH.HorarioExcepcion
            WHERE Fecha = CAST(@FechaInicioD AS DATE) AND Disponible = 1 AND Aprobado = 1
        )
        BEGIN ROLLBACK; RAISERROR('El salón no atiende los domingos.', 16, 1); RETURN; END

        DECLARE @Servicios TABLE (Orden INT IDENTITY(1,1), ServicioID INT, EmpleadoID INT);
        DECLARE @SrvList VARCHAR(500) = @ServicioIDs + ',';
        DECLARE @EmpList VARCHAR(500) = @EmpleadoIDs + ',';
        DECLARE @Pos INT = 1, @PosE INT = 1, @Next INT, @NextE INT, @SrvID INT, @EmpID INT;

        WHILE CHARINDEX(',', @SrvList, @Pos) > 0
        BEGIN
            SET @Next  = CHARINDEX(',', @SrvList, @Pos);
            SET @NextE = CHARINDEX(',', @EmpList, @PosE);
            SET @SrvID = CAST(SUBSTRING(@SrvList, @Pos,  @Next  - @Pos)  AS INT);
            SET @EmpID = CAST(SUBSTRING(@EmpList, @PosE, @NextE - @PosE) AS INT);
            INSERT INTO @Servicios (ServicioID, EmpleadoID) VALUES (@SrvID, @EmpID);
            SET @Pos = @Next + 1; SET @PosE = @NextE + 1;
        END

        DECLARE @Asignaciones TABLE (
            Orden INT, ServicioID INT, EmpleadoID INT,
            FechaInicioServicio DATETIME, FechaFinServicio DATETIME, EsParalelo BIT
        );
        DECLARE @OrdenActual INT, @SrvActual INT, @EmpActual INT;
        DECLARE @Duracion INT, @SubcatActual INT;
        DECLARE @FechaIniSrv DATETIME, @FechaFinSrv DATETIME;
        DECLARE @EmpAsignado INT, @EsParalelo BIT;

        DECLARE cur CURSOR FOR SELECT Orden, ServicioID, EmpleadoID FROM @Servicios;
        OPEN cur;
        FETCH NEXT FROM cur INTO @OrdenActual, @SrvActual, @EmpActual;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @Duracion = DuracionMin, @SubcatActual = SubcategoriaID
            FROM Servicios.Servicio WHERE ServicioID = @SrvActual;

            SET @FechaIniSrv = @FechaInicioD;
            SET @FechaFinSrv = DATEADD(MINUTE, @Duracion, @FechaInicioD);
            SET @EsParalelo  = 1;

            IF EXISTS (
                SELECT 1 FROM @Asignaciones a
                JOIN Servicios.Servicio s ON s.ServicioID = a.ServicioID
                JOIN Servicios.SubcategoriaRol sr1 ON sr1.SubcategoriaID = s.SubcategoriaID
                JOIN Servicios.SubcategoriaRol sr2 ON sr2.RolID = sr1.RolID
                WHERE sr2.SubcategoriaID = @SubcatActual AND a.EsParalelo = 1
            )
            BEGIN
                SELECT @FechaIniSrv = DATEADD(MINUTE, 5, MAX(FechaFinServicio)) FROM @Asignaciones;
                SET @FechaFinSrv = DATEADD(MINUTE, @Duracion, @FechaIniSrv);
                SET @EsParalelo  = 0;
            END

            IF CAST(@FechaFinSrv AS TIME) > '19:00'
            BEGIN
                CLOSE cur; DEALLOCATE cur; ROLLBACK;
                RAISERROR('Los servicios exceden el horario del salón (19:00).', 16, 1); RETURN;
            END

            SET @EmpAsignado = NULL;

            IF @EmpActual > 0
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM RRHH.HorarioExcepcion
                    WHERE EmpleadoID = @EmpActual AND Fecha = CAST(@FechaInicioD AS DATE)
                      AND Disponible = 0 AND Estado = 'Aprobada'
                )
                BEGIN
                    CLOSE cur; DEALLOCATE cur; ROLLBACK;
                    RAISERROR('El empleado elegido tiene día libre aprobado para esa fecha.', 16, 1); RETURN;
                END

                IF NOT EXISTS (
                    SELECT 1 FROM Agenda.CitaServicio cs
                    JOIN Agenda.Cita c ON c.CitaID = cs.CitaID
                    WHERE cs.EmpleadoID = @EmpActual AND c.EstadoID NOT IN (12, 13)
                      AND cs.FechaInicioServicio < @FechaFinSrv
                      AND cs.FechaFinServicio    > @FechaIniSrv
                )
                    SET @EmpAsignado = @EmpActual;
                ELSE
                BEGIN
                    CLOSE cur; DEALLOCATE cur; ROLLBACK;
                    RAISERROR('El empleado elegido no está disponible en ese horario.', 16, 1); RETURN;
                END
            END
            ELSE
            BEGIN
                SELECT TOP 1 @EmpAsignado = e.EmpleadoID
                FROM RRHH.Empleado     e
                JOIN RRHH.EmpleadoRol  er ON er.EmpleadoID = e.EmpleadoID
                JOIN Servicios.SubcategoriaRol sr ON sr.RolID = er.RolID
                WHERE sr.SubcategoriaID = @SubcatActual AND e.Activo = 1
                  AND er.RolID IN (3, 4, 5, 6)
                  AND EXISTS (
                      SELECT 1 FROM RRHH.HorarioEmpleado h
                      WHERE h.EmpleadoID = e.EmpleadoID AND h.DiaSemana = @DiaConvertido
                        AND h.HoraEntrada <= CAST(@FechaIniSrv AS TIME)
                        AND h.HoraSalida  >= CAST(@FechaFinSrv AS TIME) AND h.Activo = 1
                  )
                  AND NOT EXISTS (
                      SELECT 1 FROM RRHH.HorarioExcepcion ex
                      WHERE ex.EmpleadoID = e.EmpleadoID AND ex.Fecha = CAST(@FechaInicioD AS DATE)
                        AND ex.Disponible = 0 AND ex.Estado = 'Aprobada'
                  )
                  AND e.EmpleadoID NOT IN (
                      SELECT cs.EmpleadoID FROM Agenda.CitaServicio cs
                      JOIN Agenda.Cita c ON c.CitaID = cs.CitaID
                      WHERE c.EstadoID NOT IN (12, 13)
                        AND cs.FechaInicioServicio < @FechaFinSrv
                        AND cs.FechaFinServicio    > @FechaIniSrv
                  )
                  AND e.EmpleadoID NOT IN (SELECT EmpleadoID FROM @Asignaciones)
                ORDER BY NEWID();

                IF @EmpAsignado IS NULL
                BEGIN
                    CLOSE cur; DEALLOCATE cur; ROLLBACK;
                    RAISERROR('No hay personal disponible para uno de los servicios.', 16, 1); RETURN;
                END
            END

            INSERT INTO @Asignaciones (Orden, ServicioID, EmpleadoID, FechaInicioServicio, FechaFinServicio, EsParalelo)
            VALUES (@OrdenActual, @SrvActual, @EmpAsignado, @FechaIniSrv, @FechaFinSrv, @EsParalelo);
            FETCH NEXT FROM cur INTO @OrdenActual, @SrvActual, @EmpActual;
        END
        CLOSE cur; DEALLOCATE cur;

        DECLARE @CitaID INT;
        INSERT INTO Agenda.Cita (ClienteID, FechaInicio, EstadoID) VALUES (@ClienteID, @FechaInicioD, 8);
        SET @CitaID = SCOPE_IDENTITY();

        INSERT INTO Agenda.CitaEmpleado (CitaID, EmpleadoID, TipoAsignacion)
        SELECT @CitaID, EmpleadoID,
               CASE WHEN EmpleadoID IN (SELECT EmpleadoID FROM @Servicios WHERE EmpleadoID > 0)
                    THEN 'manual' ELSE 'automatica' END
        FROM @Asignaciones;

        INSERT INTO Agenda.CitaServicio
            (CitaID, ServicioID, EmpleadoID, Orden, EsParalelo, FechaInicioServicio, FechaFinServicio)
        SELECT @CitaID, ServicioID, EmpleadoID, Orden, EsParalelo, FechaInicioServicio, FechaFinServicio
        FROM @Asignaciones ORDER BY Orden;

        COMMIT;

        SELECT @CitaID AS CitaID, a.ServicioID,
               s.Nombre AS Servicio, p.Nombre AS Empleado,
               a.FechaInicioServicio, a.FechaFinServicio, a.EsParalelo,
               'Cita reservada exitosamente' AS Mensaje
        FROM @Asignaciones a
        JOIN Servicios.Servicio s ON s.ServicioID = a.ServicioID
        JOIN Personas.Persona   p ON p.PersonaID  = a.EmpleadoID
        ORDER BY a.Orden;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @Error VARCHAR(500) = ERROR_MESSAGE();
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO

-- 6. Crear solicitud de horario especial
--    FechaSolicitada como NVARCHAR para evitar conversión UTC
CREATE OR ALTER PROCEDURE Agenda.SP_CrearSolicitudEspecial
    @ClienteID       INT,
    @FechaSolicitada NVARCHAR(30),
    @TipoSolicitud   VARCHAR(30)  = NULL,
    @ServicioIDs     VARCHAR(500) = NULL,
    @Motivo          VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FechaD DATETIME = CONVERT(DATETIME, REPLACE(@FechaSolicitada,'T',' '), 120);
    INSERT INTO Agenda.SolicitudEspecial
        (ClienteID, FechaSolicitada, TipoSolicitud, ServicioIDs, Motivo, Estado, FechaCreacion)
    VALUES (@ClienteID, @FechaD, @TipoSolicitud, @ServicioIDs, @Motivo, 'Pendiente', GETDATE());
    SELECT SCOPE_IDENTITY() AS SolicitudID, 'Solicitud enviada' AS Mensaje;
END;
GO

-- 7. Obtener solicitudes del cliente
CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerSolicitudesCliente
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        SolicitudID, FechaSolicitada, TipoSolicitud,
        ServicioIDs, Motivo, Estado, MotivoRechazo, CitaID, FechaCreacion
    FROM Agenda.SolicitudEspecial
    WHERE ClienteID = @ClienteID
    ORDER BY FechaCreacion DESC;
END;
GO

-- 8. Catálogo de servicios
CREATE OR ALTER PROCEDURE Servicios.SP_ObtenerCatalogo
    @CategoriaID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.ServicioID, s.Nombre, s.Descripcion, s.DuracionMin,
        c.CategoriaID, c.Nombre    AS Categoria,
        sc.SubcategoriaID, sc.Nombre AS Subcategoria,
        sp.Precio
    FROM Servicios.Servicio             s
    JOIN Servicios.SubcategoriaServicio sc ON sc.SubcategoriaID = s.SubcategoriaID
    JOIN Servicios.CategoriaServicio    c  ON c.CategoriaID     = sc.CategoriaID
    JOIN Servicios.ServicioPrecio       sp ON sp.ServicioID     = s.ServicioID
    WHERE s.Activo = 1 AND sp.FechaFin IS NULL
      AND (@CategoriaID IS NULL OR c.CategoriaID = @CategoriaID)
    ORDER BY c.Nombre, sc.Nombre, s.Nombre;
END;
GO

-- 9. Compras del cliente (con filtro de fechas)
CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerComprasCliente
    @ClienteID  INT,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.VentaID, v.Fecha, v.Estado AS EstadoVenta, f.FacturaID,
           s.Nombre AS Item, 'Servicio' AS Tipo,
           vds.Cantidad, vds.PrecioUnitario,
           vds.PrecioUnitario * vds.Cantidad AS Total,
           f.NumeroFactura, f.Estado AS EstadoFactura
    FROM Ventas.Venta                v
    JOIN Ventas.VentaDetalleServicio vds ON vds.VentaID  = v.VentaID
    JOIN Servicios.Servicio          s   ON s.ServicioID = vds.ServicioID
    LEFT JOIN Facturacion.Factura    f   ON f.VentaID    = v.VentaID
    WHERE v.ClienteID = @ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE) >= @FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE) <= @FechaHasta)

    UNION ALL

    SELECT v.VentaID, v.Fecha, v.Estado AS EstadoVenta, f.FacturaID,
           p.Nombre AS Item, 'Producto' AS Tipo,
           vdp.Cantidad, vdp.PrecioUnitario,
           vdp.PrecioUnitario * vdp.Cantidad AS Total,
           f.NumeroFactura, f.Estado AS EstadoFactura
    FROM Ventas.Venta                v
    JOIN Ventas.VentaDetalleProducto vdp ON vdp.VentaID   = v.VentaID
    JOIN Inventario.Producto         p   ON p.ProductoID  = vdp.ProductoID
    LEFT JOIN Facturacion.Factura    f   ON f.VentaID     = v.VentaID
    WHERE v.ClienteID = @ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE) >= @FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE) <= @FechaHasta)

    ORDER BY Fecha DESC;
END;
GO

-- 10. Pagos del cliente (con filtro de fechas)
CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerPagosCliente
    @ClienteID  INT,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pg.PagoID, v.Fecha, pg.Monto, mp.Nombre AS MetodoPago,
           f.NumeroFactura, f.Estado AS EstadoFactura, v.VentaID
    FROM Ventas.Pago              pg
    JOIN Ventas.Venta             v  ON v.VentaID      = pg.VentaID
    JOIN Ventas.MetodoPago        mp ON mp.MetodoPagoID = pg.MetodoPagoID
    LEFT JOIN Facturacion.Factura f  ON f.VentaID      = v.VentaID
    WHERE v.ClienteID = @ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE) >= @FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE) <= @FechaHasta)
    ORDER BY v.Fecha DESC;
END;
GO

-- 11. Compras y pagos (esquema Cliente, con filtro)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Cliente')
    EXEC('CREATE SCHEMA Cliente');
GO

CREATE OR ALTER PROCEDURE Cliente.SP_MisCompras
    @ClienteID  INT,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.VentaID, v.Fecha, f.FacturaID, f.NumeroFactura,
           f.Estado AS EstadoFactura, s.Nombre AS Item, 'Servicio' AS Tipo,
           vds.Cantidad, vds.PrecioUnitario,
           vds.Cantidad * vds.PrecioUnitario AS Total
    FROM Ventas.Venta                v
    JOIN Facturacion.Factura         f   ON f.VentaID    = v.VentaID
    JOIN Ventas.VentaDetalleServicio vds ON vds.VentaID  = v.VentaID
    JOIN Servicios.Servicio          s   ON s.ServicioID = vds.ServicioID
    WHERE v.ClienteID = @ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE) >= @FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE) <= @FechaHasta)

    UNION ALL

    SELECT v.VentaID, v.Fecha, f.FacturaID, f.NumeroFactura,
           f.Estado AS EstadoFactura, p.Nombre AS Item, 'Producto' AS Tipo,
           vdp.Cantidad, vdp.PrecioUnitario,
           vdp.Cantidad * vdp.PrecioUnitario AS Total
    FROM Ventas.Venta                v
    JOIN Facturacion.Factura         f   ON f.VentaID    = v.VentaID
    JOIN Ventas.VentaDetalleProducto vdp ON vdp.VentaID  = v.VentaID
    JOIN Inventario.Producto         p   ON p.ProductoID = vdp.ProductoID
    WHERE v.ClienteID = @ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE) >= @FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE) <= @FechaHasta)

    ORDER BY v.Fecha DESC;
END;
GO

CREATE OR ALTER PROCEDURE Cliente.SP_MisPagos
    @ClienteID  INT,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pg.PagoID, v.Fecha, pg.Monto, mp.Nombre AS MetodoPago,
           f.NumeroFactura, f.Estado AS EstadoFactura
    FROM Ventas.Pago              pg
    JOIN Ventas.Venta              v  ON v.VentaID      = pg.VentaID
    JOIN Ventas.MetodoPago         mp ON mp.MetodoPagoID = pg.MetodoPagoID
    JOIN Facturacion.Factura       f  ON f.VentaID      = v.VentaID
    WHERE v.ClienteID = @ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE) >= @FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE) <= @FechaHasta)
    ORDER BY v.Fecha DESC;
END;
GO

-- 12. Notificaciones
CREATE OR ALTER PROCEDURE Notificaciones.SP_ObtenerNotificaciones
    @PersonaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT n.NotificacionID, n.Mensaje, n.Fecha, n.Leido,
           tn.Nombre AS TipoNotificacion
    FROM Notificaciones.Notificacion     n
    JOIN Notificaciones.TipoNotificacion tn ON tn.TipoNotificacionID = n.TipoNotificacionID
    WHERE n.PersonaID = @PersonaID
    ORDER BY n.Leido ASC, n.Fecha DESC;
END;
GO

CREATE OR ALTER PROCEDURE Notificaciones.SP_MarcarNotificacionLeida
    @NotificacionID INT,
    @PersonaID      INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Notificaciones.Notificacion SET Leido = 1
    WHERE NotificacionID = @NotificacionID AND PersonaID = @PersonaID;
    IF @@ROWCOUNT = 0 RAISERROR('Notificación no encontrada.', 16, 1);
    ELSE SELECT 'Notificación marcada como leída.' AS Mensaje;
END;
GO