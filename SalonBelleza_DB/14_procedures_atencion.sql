-- COCO Salón de Belleza · SalonBelleza_DB
-- 14 · STORED PROCEDURES · MÓDULO ATENCIÓN Y SOPORTE

USE SalonBelleza_DB;
GO

-- 1. Panel de recepción
--    RS[0] Estadísticas del día   RS[1] Próxima cita
--    RS[2] Ventas del día         RS[3] Total clientes
--    RS[4] Citas del día          RS[5] Disponibilidad personal
CREATE OR ALTER PROCEDURE Agenda.SP_PanelRecepcion
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS TotalCitas,
        SUM(CASE WHEN c.EstadoID = 8  THEN 1 ELSE 0 END) AS Programadas,
        SUM(CASE WHEN c.EstadoID = 9  THEN 1 ELSE 0 END) AS Confirmadas,
        SUM(CASE WHEN c.EstadoID = 10 THEN 1 ELSE 0 END) AS EnCurso,
        SUM(CASE WHEN c.EstadoID = 11 THEN 1 ELSE 0 END) AS Completadas
    FROM Agenda.Cita c
    WHERE CAST(c.FechaInicio AS DATE) = CAST(GETDATE() AS DATE)
      AND c.EstadoID NOT IN (12, 13);

    SELECT TOP 1
        c.CitaID, c.FechaInicio,
        p.Nombre  AS NombreCliente, p.Apellido AS ApellidoCliente,
        s.Nombre  AS Servicio,
        emp.Nombre AS NombreEmpleado, emp.Apellido AS ApellidoEmpleado,
        ec.Nombre AS Estado
    FROM Agenda.Cita              c
    JOIN Personas.Persona         p   ON p.PersonaID   = c.ClienteID
    JOIN Agenda.CitaServicio      cs  ON cs.CitaID     = c.CitaID
    JOIN Servicios.Servicio       s   ON s.ServicioID  = cs.ServicioID
    LEFT JOIN Personas.Persona    emp ON emp.PersonaID = cs.EmpleadoID
    JOIN Agenda.EstadoCita        ec  ON ec.EstadoID   = c.EstadoID
    WHERE CAST(c.FechaInicio AS DATE) = CAST(GETDATE() AS DATE)
      AND c.EstadoID IN (8, 9)
    ORDER BY c.FechaInicio ASC;

    SELECT COUNT(*) AS TotalVentas, ISNULL(SUM(pg.Monto), 0) AS TotalMonto
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID = v.VentaID
    WHERE CAST(v.Fecha AS DATE) = CAST(GETDATE() AS DATE);

    SELECT COUNT(*) AS TotalClientes,
        SUM(CASE WHEN CAST(p.FechaRegistro AS DATE) >= DATEADD(DAY,-7,GETDATE()) THEN 1 ELSE 0 END) AS NuevosEstaSemana
    FROM Ventas.Cliente c JOIN Personas.Persona p ON p.PersonaID = c.ClienteID;

    SELECT
        c.CitaID, c.FechaInicio,
        cs.FechaInicioServicio, cs.FechaFinServicio,
        cs.EsParalelo, cs.Orden,
        p.Nombre  AS NombreCliente, p.Apellido AS ApellidoCliente,
        s.Nombre  AS Servicio,
        emp.Nombre  AS NombreEmpleado, emp.Apellido AS ApellidoEmpleado,
        ec.EstadoID, ec.Nombre AS Estado,
        sp.Precio
    FROM Agenda.Cita              c
    JOIN Personas.Persona         p   ON p.PersonaID   = c.ClienteID
    JOIN Agenda.CitaServicio      cs  ON cs.CitaID     = c.CitaID
    JOIN Servicios.Servicio       s   ON s.ServicioID  = cs.ServicioID
    LEFT JOIN Personas.Persona    emp ON emp.PersonaID = cs.EmpleadoID
    JOIN Agenda.EstadoCita        ec  ON ec.EstadoID   = c.EstadoID
    JOIN Servicios.ServicioPrecio sp  ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
    WHERE CAST(c.FechaInicio AS DATE) = CAST(GETDATE() AS DATE)
      AND c.EstadoID NOT IN (12, 13)
    ORDER BY c.FechaInicio ASC, cs.Orden ASC;

    SELECT
        e.EmpleadoID, p.Nombre, p.Apellido,
        STRING_AGG(r.NombreRol, ' / ') AS NombreRol,
        COUNT(DISTINCT cs.CitaServicioID) AS CitasHoy,
        CASE WHEN EXISTS (
            SELECT 1 FROM Agenda.CitaServicio cs2
            JOIN Agenda.Cita c2 ON c2.CitaID = cs2.CitaID
            WHERE cs2.EmpleadoID = e.EmpleadoID AND c2.EstadoID IN (9,10)
              AND cs2.FechaInicioServicio <= GETDATE()
              AND cs2.FechaFinServicio    >= GETDATE()
        ) THEN 'Ocupada' ELSE 'Libre' END AS EstadoActual
    FROM RRHH.Empleado    e
    JOIN Personas.Persona  p  ON p.PersonaID   = e.EmpleadoID
    JOIN RRHH.EmpleadoRol  er ON er.EmpleadoID = e.EmpleadoID
    JOIN RRHH.Rol          r  ON r.RolID       = er.RolID
    LEFT JOIN Agenda.CitaServicio cs ON cs.EmpleadoID = e.EmpleadoID
        AND CAST(cs.FechaInicioServicio AS DATE) = CAST(GETDATE() AS DATE)
    WHERE e.Activo = 1 AND r.RolID IN (3,4,5,6)
    GROUP BY e.EmpleadoID, p.Nombre, p.Apellido
    ORDER BY p.Nombre;
END;
GO

-- 2. Gestión de citas (con filtros)
CREATE OR ALTER PROCEDURE Agenda.SP_GestionCitas
    @Fecha      DATE = NULL,
    @EmpleadoID INT  = NULL,
    @EstadoID   INT  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.CitaID, c.FechaInicio,
        cs.FechaInicioServicio, cs.FechaFinServicio,
        cs.EsParalelo, cs.Orden,
        p.Nombre  AS NombreCliente, p.Apellido AS ApellidoCliente,
        fc.Alergias,
        s.Nombre  AS Servicio, s.DuracionMin,
        sp.Precio,
        emp.Nombre  AS NombreEmpleado, emp.Apellido AS ApellidoEmpleado,
        ec.EstadoID, ec.Nombre AS Estado
    FROM Agenda.Cita              c
    JOIN Personas.Persona         p   ON p.PersonaID   = c.ClienteID
    JOIN Agenda.CitaServicio      cs  ON cs.CitaID     = c.CitaID
    JOIN Servicios.Servicio       s   ON s.ServicioID  = cs.ServicioID
    LEFT JOIN Personas.Persona    emp ON emp.PersonaID = cs.EmpleadoID
    JOIN Agenda.EstadoCita        ec  ON ec.EstadoID   = c.EstadoID
    JOIN Servicios.ServicioPrecio sp  ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
    LEFT JOIN Ventas.ClienteDetalle fc ON fc.ClienteID = c.ClienteID
    WHERE (@Fecha      IS NULL OR CAST(c.FechaInicio AS DATE) = @Fecha)
      AND (@EmpleadoID IS NULL OR cs.EmpleadoID = @EmpleadoID)
      AND (@EstadoID   IS NULL OR c.EstadoID    = @EstadoID)
      AND c.EstadoID NOT IN (12, 13)
    ORDER BY c.FechaInicio ASC, cs.Orden ASC;
END;
GO

-- 3. Confirmar cita
CREATE OR ALTER PROCEDURE Agenda.SP_ConfirmarCita
    @CitaID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Agenda.Cita SET EstadoID = 9 WHERE CitaID = @CitaID;
    SELECT 'Cita confirmada.' AS Mensaje;
END;
GO

-- 4. Crear cita desde recepción
--    @Servicios formato: 'ServicioID:EmpleadoID:EsParalelo,...'
--    Verifica día libre y conflicto de horario por empleado
CREATE OR ALTER PROCEDURE Agenda.SP_CrearCitaRecepcion
    @ClienteID   INT,
    @FechaInicio NVARCHAR(30),
    @Servicios   VARCHAR(MAX),
    @EstadoID    INT = 8,
    @Notas       VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @FechaInicioD DATETIME = CONVERT(DATETIME, REPLACE(@FechaInicio, 'T', ' '), 120);
        DECLARE @CitaID INT;

        INSERT INTO Agenda.Cita (ClienteID, FechaInicio, EstadoID)
        VALUES (@ClienteID, @FechaInicioD, @EstadoID);
        SET @CitaID = SCOPE_IDENTITY();

        DECLARE @List  VARCHAR(MAX) = @Servicios + ',';
        DECLARE @Pos   INT = 1, @Next INT;
        DECLARE @Item  VARCHAR(100);
        DECLARE @SrvID INT, @EmpID INT, @Paralelo BIT, @Dur INT;
        DECLARE @FecAct    DATETIME = @FechaInicioD;
        DECLARE @FecIniAnt DATETIME = @FechaInicioD;
        DECLARE @FecFin    DATETIME;
        DECLARE @Orden     INT = 1;
        DECLARE @EsPrimero BIT = 1;

        WHILE CHARINDEX(',', @List, @Pos) > 0
        BEGIN
            SET @Next = CHARINDEX(',', @List, @Pos);
            SET @Item = SUBSTRING(@List, @Pos, @Next - @Pos);
            DECLARE @P1 INT = CHARINDEX(':', @Item);
            DECLARE @P2 INT = CHARINDEX(':', @Item, @P1 + 1);
            SET @SrvID    = CAST(SUBSTRING(@Item, 1, @P1 - 1) AS INT);
            SET @EmpID    = CAST(SUBSTRING(@Item, @P1 + 1, @P2 - @P1 - 1) AS INT);
            SET @Paralelo = CAST(SUBSTRING(@Item, @P2 + 1, LEN(@Item)) AS BIT);
            SELECT @Dur = DuracionMin FROM Servicios.Servicio WHERE ServicioID = @SrvID;
            IF @Paralelo = 1 AND @EsPrimero = 0 SET @FecAct = @FecIniAnt;
            SET @FecFin = DATEADD(MINUTE, @Dur, @FecAct);

            -- Verificar día libre aprobado
            IF EXISTS (
                SELECT 1 FROM RRHH.HorarioExcepcion
                WHERE EmpleadoID = @EmpID AND Fecha = CAST(@FechaInicioD AS DATE)
                  AND Disponible = 0 AND Estado = 'Aprobada'
            )
            BEGIN ROLLBACK; RAISERROR('El empleado tiene día libre aprobado para esa fecha.', 16, 1); RETURN; END

            -- Verificar conflicto de horario
            IF EXISTS (
                SELECT 1 FROM Agenda.CitaServicio cs
                JOIN Agenda.Cita c ON c.CitaID = cs.CitaID
                WHERE cs.EmpleadoID = @EmpID AND c.EstadoID NOT IN (12, 13)
                  AND cs.FechaInicioServicio < @FecFin AND cs.FechaFinServicio > @FecAct
            )
            BEGIN ROLLBACK; RAISERROR('El empleado no está disponible en ese horario.', 16, 1); RETURN; END

            INSERT INTO Agenda.CitaServicio
                (CitaID, ServicioID, EmpleadoID, Orden, EsParalelo, FechaInicioServicio, FechaFinServicio)
            VALUES (@CitaID, @SrvID, @EmpID, @Orden, @Paralelo, @FecAct, @FecFin);

            IF NOT EXISTS (SELECT 1 FROM Agenda.CitaEmpleado WHERE CitaID = @CitaID AND EmpleadoID = @EmpID)
                INSERT INTO Agenda.CitaEmpleado (CitaID, EmpleadoID, TipoAsignacion) VALUES (@CitaID, @EmpID, 'manual');

            SET @FecIniAnt = @FecAct;
            IF @Paralelo = 0 SET @FecAct = DATEADD(MINUTE, @Dur + 5, @FecAct);
            SET @Orden = @Orden + 1; SET @EsPrimero = 0; SET @Pos = @Next + 1;
        END

        COMMIT;
        SELECT @CitaID AS CitaID, 'Cita creada correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @Error VARCHAR(500) = ERROR_MESSAGE();
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO

-- 5. Editar cita desde recepción
CREATE OR ALTER PROCEDURE Agenda.SP_EditarCitaRecepcion
    @CitaID     INT,
    @EstadoID   INT          = NULL,
    @NuevaFecha NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @NuevaFechaD DATETIME = NULL;
        IF @NuevaFecha IS NOT NULL
            SET @NuevaFechaD = CONVERT(DATETIME, REPLACE(@NuevaFecha, 'T', ' '), 120);

        IF @EstadoID IS NOT NULL
            UPDATE Agenda.Cita SET EstadoID = @EstadoID WHERE CitaID = @CitaID;

        IF @NuevaFechaD IS NOT NULL
        BEGIN
            DECLARE @FecAct   DATETIME = @NuevaFechaD;
            DECLARE @CsID     INT, @SrvID INT, @EmpID INT, @Dur INT, @EsParalelo BIT;
            DECLARE @FecIniAnterior DATETIME = @NuevaFechaD;

            DECLARE cur CURSOR FOR
                SELECT CitaServicioID, ServicioID, EmpleadoID, EsParalelo
                FROM Agenda.CitaServicio WHERE CitaID = @CitaID ORDER BY Orden;

            OPEN cur;
            FETCH NEXT FROM cur INTO @CsID, @SrvID, @EmpID, @EsParalelo;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SELECT @Dur = DuracionMin FROM Servicios.Servicio WHERE ServicioID = @SrvID;
                IF @EsParalelo = 1 SET @FecAct = @FecIniAnterior;
                DECLARE @FecFin DATETIME = DATEADD(MINUTE, @Dur, @FecAct);

                IF EXISTS (
                    SELECT 1 FROM Agenda.CitaServicio cs
                    JOIN Agenda.Cita c ON c.CitaID = cs.CitaID
                    WHERE cs.EmpleadoID = @EmpID AND cs.CitaID <> @CitaID
                      AND c.EstadoID NOT IN (12, 13)
                      AND cs.FechaInicioServicio < @FecFin AND cs.FechaFinServicio > @FecAct
                )
                BEGIN
                    CLOSE cur; DEALLOCATE cur; ROLLBACK;
                    RAISERROR('El empleado no está disponible en ese horario.', 16, 1); RETURN;
                END

                UPDATE Agenda.CitaServicio
                SET FechaInicioServicio = @FecAct, FechaFinServicio = @FecFin
                WHERE CitaServicioID = @CsID;

                SET @FecIniAnterior = @FecAct;
                IF ISNULL(@EsParalelo, 0) = 0 SET @FecAct = DATEADD(MINUTE, @Dur + 5, @FecAct);
                FETCH NEXT FROM cur INTO @CsID, @SrvID, @EmpID, @EsParalelo;
            END
            CLOSE cur; DEALLOCATE cur;
            UPDATE Agenda.Cita SET FechaInicio = @NuevaFechaD WHERE CitaID = @CitaID;
        END

        COMMIT;
        SELECT 'Cita actualizada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @Error VARCHAR(500) = ERROR_MESSAGE();
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO

-- 6. Cancelar cita desde recepción
CREATE OR ALTER PROCEDURE Agenda.SP_CancelarCitaRecepcion
    @CitaID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Agenda.Cita SET EstadoID = 12 WHERE CitaID = @CitaID;
    SELECT 'Cita cancelada.' AS Mensaje;
END;
GO

-- 7. Obtener solicitudes especiales (recepción
--    Devuelve NombresServicios usando STRING_AGG + STRING_SPLIT
--    Fechas devueltas como NVARCHAR para evitar conversión UTC
CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerSolicitudes
    @Estado VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.SolicitudID, s.ClienteID,
        p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
        p.Telefono,
        CONVERT(NVARCHAR(19), s.FechaSolicitada, 120) AS FechaSolicitada,
        s.TipoSolicitud, s.ServicioIDs,
        (SELECT STRING_AGG(sv.Nombre, ', ')
         FROM STRING_SPLIT(ISNULL(s.ServicioIDs,''), ',') sp
         JOIN Servicios.Servicio sv ON sv.ServicioID = TRY_CAST(sp.value AS INT)
        ) AS NombresServicios,
        s.Motivo, s.Estado, s.MotivoRechazo,
        s.CitaID, s.FechaCreacion
    FROM Agenda.SolicitudEspecial s
    JOIN Personas.Persona          p ON p.PersonaID = s.ClienteID
    WHERE (@Estado IS NULL OR s.Estado = @Estado)
    ORDER BY s.FechaCreacion DESC;
END;
GO

-- 8. Aprobar solicitud especial (crea cita)
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_AprobarSolicitud
    @SolicitudID     INT,
    @FechaConfirmada NVARCHAR(30),
    @EmpleadoID      INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @ClienteID   INT;
        DECLARE @ServicioIDs VARCHAR(500);
        SELECT @ClienteID = ClienteID, @ServicioIDs = ServicioIDs
        FROM Agenda.SolicitudEspecial
        WHERE SolicitudID = @SolicitudID;

        DECLARE @FechaD DATETIME = CONVERT(DATETIME, REPLACE(@FechaConfirmada,'T',' '), 120);
        DECLARE @CitaID INT;
        INSERT INTO Agenda.Cita (ClienteID, FechaInicio, EstadoID)
        VALUES (@ClienteID, @FechaD, 9);
        SET @CitaID = SCOPE_IDENTITY();

        IF @ServicioIDs IS NOT NULL
        BEGIN
            DECLARE @SrvList VARCHAR(500) = @ServicioIDs + ',';
            DECLARE @Pos INT = 1, @Next INT, @SrvID INT, @Orden INT = 1;
            DECLARE @Dur INT, @FIni DATETIME = @FechaD, @FFin DATETIME;
            DECLARE @SubcatID INT, @EmpAsignado INT;

            WHILE CHARINDEX(',', @SrvList, @Pos) > 0
            BEGIN
                SET @Next  = CHARINDEX(',', @SrvList, @Pos);
                SET @SrvID = CAST(SUBSTRING(@SrvList, @Pos, @Next - @Pos) AS INT);
                SELECT @Dur = DuracionMin, @SubcatID = SubcategoriaID 
                FROM Servicios.Servicio WHERE ServicioID = @SrvID;
                SET @FFin = DATEADD(MINUTE, @Dur, @FIni);

                -- Usar empleado manual o asignar automáticamente
                SET @EmpAsignado = @EmpleadoID;
                IF @EmpAsignado IS NULL
                BEGIN
                    SELECT TOP 1 @EmpAsignado = e.EmpleadoID
                    FROM RRHH.Empleado e
                    JOIN RRHH.EmpleadoRol er ON er.EmpleadoID = e.EmpleadoID
                    JOIN Servicios.SubcategoriaRol sr ON sr.RolID = er.RolID
                    WHERE sr.SubcategoriaID = @SubcatID
                      AND e.Activo = 1
                      AND er.RolID IN (3,4,5,6)
                    ORDER BY NEWID();
                END

                INSERT INTO Agenda.CitaServicio
                    (CitaID, ServicioID, EmpleadoID, Orden, EsParalelo, FechaInicioServicio, FechaFinServicio)
                VALUES (@CitaID, @SrvID, @EmpAsignado, @Orden, 0, @FIni, @FFin);

                IF @EmpAsignado IS NOT NULL AND NOT EXISTS (
                    SELECT 1 FROM Agenda.CitaEmpleado WHERE CitaID = @CitaID AND EmpleadoID = @EmpAsignado
                )
                    INSERT INTO Agenda.CitaEmpleado (CitaID, EmpleadoID, TipoAsignacion)
                    VALUES (@CitaID, @EmpAsignado, CASE WHEN @EmpleadoID IS NOT NULL THEN 'manual' ELSE 'automatica' END);

                SET @FIni  = DATEADD(MINUTE, 5, @FFin);
                SET @Orden = @Orden + 1;
                SET @Pos   = @Next + 1;
            END
        END

        UPDATE Agenda.SolicitudEspecial
        SET Estado = 'Aprobada', CitaID = @CitaID
        WHERE SolicitudID = @SolicitudID;

        INSERT INTO Notificaciones.Notificacion
            (PersonaID, TipoNotificacionID, Mensaje, Leido, Fecha)
        VALUES (
            @ClienteID, 8,
            'Tu solicitud de horario especial fue aprobada. Tu cita está confirmada para el ' +
            CONVERT(VARCHAR, @FechaD, 103) + ' a las ' + CONVERT(VARCHAR(5), @FechaD, 108) + '.',
            0, GETDATE()
        );

        COMMIT;
        SELECT @CitaID AS CitaID, 'Solicitud aprobada' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @Err VARCHAR(500) = ERROR_MESSAGE();
        RAISERROR(@Err, 16, 1);
    END CATCH
END;
GO

-- 9. Rechazar solicitud especial
CREATE OR ALTER PROCEDURE Agenda.SP_RechazarSolicitud
    @SolicitudID   INT,
    @MotivoRechazo VARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ClienteID INT;
    SELECT @ClienteID = ClienteID FROM Agenda.SolicitudEspecial WHERE SolicitudID = @SolicitudID;

    UPDATE Agenda.SolicitudEspecial SET Estado = 'Rechazada', MotivoRechazo = @MotivoRechazo
    WHERE SolicitudID = @SolicitudID;

    -- TipoNotificacionID 9 = solicitud_rechazada
    INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje, Leido, Fecha)
    VALUES (@ClienteID, 9,
        'Tu solicitud de horario especial fue rechazada.' + ISNULL(' Motivo: ' + @MotivoRechazo, ''),
        0, GETDATE());

    SELECT 'Solicitud rechazada' AS Mensaje;
END;
GO

-- 10. Listar excepciones pendientes de aprobación
--    Fechas devueltas como NVARCHAR(10) para evitar conversión UTC
CREATE OR ALTER PROCEDURE RRHH.SP_ListarExcepcionesPendientes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        he.ExcepcionID, he.EmpleadoID,
        p.Nombre, p.Apellido,
        STRING_AGG(r.NombreRol, ', ') WITHIN GROUP (ORDER BY r.RolID) AS NombreRol,
        CONVERT(NVARCHAR(10), he.Fecha, 120) AS Fecha,
        he.Disponible, he.Motivo, he.Aprobado, he.Estado, he.TipoSolicitud
    FROM RRHH.HorarioExcepcion    he
    JOIN Personas.Persona          p  ON p.PersonaID   = he.EmpleadoID
    JOIN RRHH.EmpleadoRol          er ON er.EmpleadoID = he.EmpleadoID
    JOIN RRHH.Rol                  r  ON r.RolID       = er.RolID
    WHERE he.Estado = 'Pendiente' OR he.Estado IS NULL
    GROUP BY he.ExcepcionID, he.EmpleadoID, p.Nombre, p.Apellido,
             he.Fecha, he.Disponible, he.Motivo, he.Aprobado,
             he.Estado, he.TipoSolicitud
    ORDER BY he.Fecha;
END;
GO

-- 11. Aprobar / rechazar excepción de horario
--    Si es día libre aprobado: cancela citas existentes y notifica clientes
CREATE OR ALTER PROCEDURE RRHH.SP_AprobarExcepcion
    @ExcepcionID INT,
    @Aprobado    BIT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EmpleadoID INT, @Disponible BIT, @Fecha DATE;
    SELECT @EmpleadoID = EmpleadoID, @Disponible = Disponible, @Fecha = Fecha
    FROM RRHH.HorarioExcepcion WHERE ExcepcionID = @ExcepcionID;

    UPDATE RRHH.HorarioExcepcion
    SET Aprobado = @Aprobado,
        Estado   = CASE WHEN @Aprobado = 1 THEN 'Aprobada' ELSE 'Rechazada' END
    WHERE ExcepcionID = @ExcepcionID;

    -- Cancelar citas existentes si es día libre aprobado
    IF @Aprobado = 1 AND @Disponible = 0
    BEGIN
        UPDATE Agenda.Cita SET EstadoID = 12
        WHERE CitaID IN (
            SELECT DISTINCT c.CitaID FROM Agenda.CitaServicio cs
            JOIN Agenda.Cita c ON c.CitaID = cs.CitaID
            WHERE cs.EmpleadoID = @EmpleadoID
              AND CAST(cs.FechaInicioServicio AS DATE) = @Fecha
              AND c.EstadoID NOT IN (11, 12, 13)
        );

        -- Notificar clientes afectados (TipoNotificacionID 7)
        INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje, Leido, Fecha)
        SELECT DISTINCT c.ClienteID, 7,
            'Tu cita del ' + CONVERT(VARCHAR, @Fecha, 103) +
            ' fue cancelada debido a la ausencia del personal asignado. ' +
            'Por favor contáctanos para reagendar.',
            0, GETDATE()
        FROM Agenda.CitaServicio cs
        JOIN Agenda.Cita c ON c.CitaID = cs.CitaID
        WHERE cs.EmpleadoID = @EmpleadoID
          AND CAST(cs.FechaInicioServicio AS DATE) = @Fecha
          AND c.EstadoID = 12;
    END

    -- Notificar al empleado (TipoNotificacionID 4)
    DECLARE @Msg VARCHAR(300);
    IF @Aprobado = 1
        SET @Msg = 'Tu solicitud de ' +
            CASE WHEN @Disponible = 1 THEN 'turno extra' ELSE 'día libre' END +
            ' para el ' + CONVERT(VARCHAR, @Fecha, 103) + ' fue aprobada.';
    ELSE
        SET @Msg = 'Tu solicitud de ' +
            CASE WHEN @Disponible = 1 THEN 'turno extra' ELSE 'día libre' END +
            ' para el ' + CONVERT(VARCHAR, @Fecha, 103) + ' fue rechazada.';

    INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje, Leido, Fecha)
    VALUES (@EmpleadoID, 4, @Msg, 0, GETDATE());

    SELECT CASE WHEN @Aprobado = 1 THEN 'Excepción aprobada correctamente.'
                ELSE 'Excepción rechazada correctamente.' END AS Mensaje;
END;
GO

-- 12. Obtener clientes (con búsqueda y filtros)
CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerClientes
    @Busqueda VARCHAR(100) = NULL,
    @Filtro   VARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.PersonaID AS ClienteID,
        p.Nombre, p.Apellido, p.Telefono, p.Email, p.FechaRegistro,
        cd.Alergias, cd.Contraindicaciones,
        COUNT(DISTINCT v.VentaID) AS TotalVisitas,
        MAX(v.Fecha) AS UltimaCita
    FROM Personas.Persona        p
    JOIN Ventas.Cliente           cl ON cl.ClienteID  = p.PersonaID
    LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID = p.PersonaID
    LEFT JOIN Ventas.Venta         v  ON v.ClienteID  = p.PersonaID
    WHERE (
        @Busqueda IS NULL OR
        p.Nombre   LIKE '%'+@Busqueda+'%' OR p.Apellido LIKE '%'+@Busqueda+'%' OR
        p.Telefono LIKE '%'+@Busqueda+'%' OR p.Email    LIKE '%'+@Busqueda+'%'
    )
    AND (
        @Filtro IS NULL OR
        (@Filtro = 'alergias' AND cd.Alergias IS NOT NULL) OR
        (@Filtro = 'nuevos'   AND p.FechaRegistro >= DATEADD(MONTH,-1,GETDATE()))
    )
    GROUP BY p.PersonaID, p.Nombre, p.Apellido, p.Telefono,
             p.Email, p.FechaRegistro, cd.Alergias, cd.Contraindicaciones
    HAVING (@Filtro IS NULL OR @Filtro <> 'frecuentes' OR COUNT(DISTINCT v.VentaID) >= 3)
    ORDER BY p.Nombre ASC;
END;
GO

-- 13. Registrar venta y factura
--    @Servicios formato: 'ServicioID:Qty:Precio:EmpleadoID,...'
--    @Productos formato: 'ProductoID:Qty:Precio,...'
--    DescuentoMonto calculado en el frontend sobre servicios en promoción
CREATE OR ALTER PROCEDURE Ventas.SP_RegistrarVenta
    @ClienteID      INT,
    @EmpleadoID     INT          = NULL,
    @MetodoPagoID   INT,
    @Monto          DECIMAL(10,2),
    @Referencia     VARCHAR(100) = NULL,
    @Servicios      VARCHAR(MAX) = NULL,
    @Productos      VARCHAR(MAX) = NULL,
    @DescuentoPct   DECIMAL(5,2)  = 0,
    @PromocionID    INT           = NULL,
    @DescuentoMonto DECIMAL(10,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF @Servicios IS NULL AND @Productos IS NULL
        BEGIN ROLLBACK; RAISERROR('Debe incluir al menos un servicio o producto.',16,1); RETURN; END

        DECLARE @VentaID INT;
        INSERT INTO Ventas.Venta (ClienteID, EmpleadoID, Estado, DescuentoPct, DescuentoMonto, PromocionID)
        VALUES (@ClienteID, @EmpleadoID, 'pendiente', @DescuentoPct, @DescuentoMonto, @PromocionID);
        SET @VentaID = SCOPE_IDENTITY();

        IF @Servicios IS NOT NULL
        BEGIN
            DECLARE @SrvList VARCHAR(MAX) = @Servicios + ',';
            DECLARE @SrvPos INT = 1, @SrvNext INT;
            DECLARE @SrvItem VARCHAR(200);
            DECLARE @P1 VARCHAR(50), @P2 VARCHAR(50), @P3 VARCHAR(50), @P4 VARCHAR(50);
            DECLARE @SrvID INT, @SrvQty INT, @SrvPrice DECIMAL(10,2), @SrvEmpID INT;

            WHILE CHARINDEX(',',@SrvList,@SrvPos) > 0
            BEGIN
                SET @SrvNext = CHARINDEX(',',@SrvList,@SrvPos);
                SET @SrvItem = SUBSTRING(@SrvList,@SrvPos,@SrvNext-@SrvPos);
                SET @P1 = SUBSTRING(@SrvItem,1,CHARINDEX(':',@SrvItem)-1);
                SET @SrvItem = SUBSTRING(@SrvItem,CHARINDEX(':',@SrvItem)+1,LEN(@SrvItem));
                SET @P2 = SUBSTRING(@SrvItem,1,CHARINDEX(':',@SrvItem)-1);
                SET @SrvItem = SUBSTRING(@SrvItem,CHARINDEX(':',@SrvItem)+1,LEN(@SrvItem));
                SET @P3 = SUBSTRING(@SrvItem,1,CHARINDEX(':',@SrvItem)-1);
                SET @P4 = SUBSTRING(@SrvItem,CHARINDEX(':',@SrvItem)+1,LEN(@SrvItem));
                SET @SrvID    = CAST(@P1 AS INT);
                SET @SrvQty   = CAST(@P2 AS INT);
                SET @SrvPrice = CAST(@P3 AS DECIMAL(10,2));
                SET @SrvEmpID = CASE WHEN ISNUMERIC(@P4)=1 AND CAST(@P4 AS INT)>0 THEN CAST(@P4 AS INT) ELSE NULL END;
                INSERT INTO Ventas.VentaDetalleServicio(VentaID,ServicioID,Cantidad,PrecioUnitario,EmpleadoID)
                VALUES(@VentaID,@SrvID,@SrvQty,@SrvPrice,@SrvEmpID);
                SET @SrvPos = @SrvNext + 1;
            END
        END

        IF @Productos IS NOT NULL
        BEGIN
            DECLARE @PrdList VARCHAR(MAX) = @Productos+',';
            DECLARE @PrdPos INT=1, @PrdNext INT;
            DECLARE @PrdItem VARCHAR(200);
            DECLARE @Q1 VARCHAR(50), @Q2 VARCHAR(50), @Q3 VARCHAR(50);
            DECLARE @PrdID INT, @PrdQty INT, @PrdPrice DECIMAL(10,2);

            WHILE CHARINDEX(',',@PrdList,@PrdPos)>0
            BEGIN
                SET @PrdNext=CHARINDEX(',',@PrdList,@PrdPos);
                SET @PrdItem=SUBSTRING(@PrdList,@PrdPos,@PrdNext-@PrdPos);
                SET @Q1=SUBSTRING(@PrdItem,1,CHARINDEX(':',@PrdItem)-1);
                SET @PrdItem=SUBSTRING(@PrdItem,CHARINDEX(':',@PrdItem)+1,LEN(@PrdItem));
                SET @Q2=SUBSTRING(@PrdItem,1,CHARINDEX(':',@PrdItem)-1);
                SET @Q3=SUBSTRING(@PrdItem,CHARINDEX(':',@PrdItem)+1,LEN(@PrdItem));
                SET @PrdID=CAST(@Q1 AS INT); SET @PrdQty=CAST(@Q2 AS INT); SET @PrdPrice=CAST(@Q3 AS DECIMAL(10,2));
                INSERT INTO Ventas.VentaDetalleProducto(VentaID,ProductoID,Cantidad,PrecioUnitario)
                VALUES(@VentaID,@PrdID,@PrdQty,@PrdPrice);
                UPDATE Inventario.Producto SET StockActual=StockActual-@PrdQty WHERE ProductoID=@PrdID;
                INSERT INTO Inventario.MovimientoInventario(ProductoID,EsEntrada,Cantidad) VALUES(@PrdID,0,@PrdQty);
                SET @PrdPos=@PrdNext+1;
            END
        END

        UPDATE Ventas.Venta SET Estado='pagado' WHERE VentaID=@VentaID;
        DECLARE @NumeroFactura VARCHAR(50)='COCO-'+RIGHT('000'+CAST(@VentaID AS VARCHAR),4);
        DECLARE @FacturaID INT;
        INSERT INTO Facturacion.Factura(VentaID,NumeroFactura,Estado) VALUES(@VentaID,@NumeroFactura,'emitida');
        SET @FacturaID=SCOPE_IDENTITY();
        INSERT INTO Ventas.Pago(VentaID,MetodoPagoID,Monto) VALUES(@VentaID,@MetodoPagoID,@Monto);
        UPDATE Facturacion.Factura SET Estado='pagada' WHERE FacturaID=@FacturaID;

        COMMIT;
        SELECT @VentaID AS VentaID, @NumeroFactura AS NumeroFactura,
               @Monto AS Total, 'Venta registrada y factura generada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @ErrMsg VARCHAR(500)=ERROR_MESSAGE();
        RAISERROR(@ErrMsg,16,1);
    END CATCH
END;
GO

-- 14. Obtener facturas
--    Total calculado con subconsultas para evitar multiplicación de filas
CREATE OR ALTER PROCEDURE Facturacion.SP_ObtenerFacturas
    @Estado     VARCHAR(20) = NULL,
    @FechaDesde DATE        = NULL,
    @FechaHasta DATE        = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        f.FacturaID, f.NumeroFactura, f.Fecha, f.Estado, f.VentaID,
        p.Nombre  AS NombreCliente,  p.Apellido  AS ApellidoCliente,
        emp.Nombre AS NombreEmpleado, emp.Apellido AS ApellidoEmpleado,
        ISNULL((SELECT SUM(PrecioUnitario * Cantidad) FROM Ventas.VentaDetalleServicio WHERE VentaID = v.VentaID), 0) +
        ISNULL((SELECT SUM(PrecioUnitario * Cantidad) FROM Ventas.VentaDetalleProducto WHERE VentaID = v.VentaID), 0) AS Total
    FROM Facturacion.Factura              f
    JOIN Ventas.Venta                     v   ON v.VentaID   = f.VentaID
    JOIN Personas.Persona                 p   ON p.PersonaID = v.ClienteID
    LEFT JOIN Personas.Persona            emp ON emp.PersonaID = v.EmpleadoID
    WHERE (@Estado     IS NULL OR f.Estado = @Estado)
      AND (@FechaDesde IS NULL OR CAST(f.Fecha AS DATE) >= @FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(f.Fecha AS DATE) <= @FechaHasta)
    ORDER BY f.Fecha DESC;
END;
GO

-- 15. Detalle de factura
--    RS[0] Cabecera  RS[1] Servicios  RS[2] Productos
CREATE OR ALTER PROCEDURE Facturacion.SP_DetalleFactura
    @FacturaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        f.FacturaID, f.NumeroFactura, f.Fecha, f.Estado,
        p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
        mp.Nombre AS MetodoPago, pg.Monto AS Total,
        ISNULL(v.DescuentoPct,0) AS DescuentoPct, ISNULL(v.DescuentoMonto,0) AS DescuentoMonto
    FROM Facturacion.Factura    f
    JOIN Ventas.Venta           v   ON v.VentaID      = f.VentaID
    JOIN Personas.Persona       p   ON p.PersonaID    = v.ClienteID
    LEFT JOIN Ventas.Pago       pg  ON pg.VentaID     = v.VentaID
    LEFT JOIN Ventas.MetodoPago mp  ON mp.MetodoPagoID = pg.MetodoPagoID
    WHERE f.FacturaID = @FacturaID;

    SELECT
        s.Nombre AS Item, 'Servicio' AS Tipo,
        vds.Cantidad, ISNULL(sp.Precio, vds.PrecioUnitario) AS PrecioUnitario,
        vds.PrecioUnitario * vds.Cantidad AS Subtotal,
        emp.Nombre AS NombreEmpleado, emp.Apellido AS ApellidoEmpleado
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta                v   ON v.VentaID    = vds.VentaID
    JOIN Facturacion.Factura         f   ON f.VentaID    = v.VentaID
    JOIN Servicios.Servicio          s   ON s.ServicioID = vds.ServicioID
    LEFT JOIN Servicios.ServicioPrecio sp ON sp.ServicioID = vds.ServicioID AND sp.FechaFin IS NULL
    LEFT JOIN Personas.Persona       emp ON emp.PersonaID = vds.EmpleadoID
    WHERE f.FacturaID = @FacturaID;

    SELECT
        pr.Nombre AS Item, 'Producto' AS Tipo,
        vdp.Cantidad, vdp.PrecioUnitario,
        vdp.Cantidad * vdp.PrecioUnitario AS Subtotal,
        NULL AS NombreEmpleado, NULL AS ApellidoEmpleado
    FROM Ventas.VentaDetalleProducto vdp
    JOIN Ventas.Venta                v  ON v.VentaID    = vdp.VentaID
    JOIN Facturacion.Factura         f  ON f.VentaID    = v.VentaID
    JOIN Inventario.Producto         pr ON pr.ProductoID = vdp.ProductoID
    WHERE f.FacturaID = @FacturaID;
END;
GO

-- 16. Promociones activas
--    RS[0] Generales  RS[1] Servicios con nombre  RS[2] Cumpleaños
CREATE OR ALTER PROCEDURE Marketing.SP_ObtenerPromocionesActivas
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.PromocionID, p.Nombre, p.Descuento, p.Descripcion,
           p.FechaInicio, p.FechaFin,
           ISNULL(p.TipoPromocion, 'general') AS TipoPromocion,
           COUNT(ps.ServicioID) AS TotalServicios
    FROM Marketing.Promocion p
    LEFT JOIN Marketing.PromocionServicio ps ON ps.PromocionID = p.PromocionID
    WHERE p.Activo = 1
      AND GETDATE() BETWEEN p.FechaInicio AND p.FechaFin
      AND ISNULL(p.TipoPromocion, 'general') <> 'cumpleanos'
    GROUP BY p.PromocionID, p.Nombre, p.Descuento, p.Descripcion,
             p.FechaInicio, p.FechaFin, p.TipoPromocion
    ORDER BY p.Nombre;

    SELECT ps.PromocionID, ps.ServicioID, s.Nombre AS NombreServicio
    FROM Marketing.PromocionServicio ps
    JOIN Marketing.Promocion   p ON p.PromocionID = ps.PromocionID
    JOIN Servicios.Servicio    s ON s.ServicioID  = ps.ServicioID
    WHERE p.Activo = 1
      AND GETDATE() BETWEEN p.FechaInicio AND p.FechaFin
      AND ISNULL(p.TipoPromocion, 'general') <> 'cumpleanos';

    SELECT p.PromocionID, p.Nombre, p.Descuento, p.Descripcion,
           p.FechaInicio, p.FechaFin, 'cumpleanos' AS TipoPromocion,
           COUNT(ps.ServicioID) AS TotalServicios
    FROM Marketing.Promocion p
    LEFT JOIN Marketing.PromocionServicio ps ON ps.PromocionID = p.PromocionID
    WHERE p.Activo = 1 AND p.TipoPromocion = 'cumpleanos'
    GROUP BY p.PromocionID, p.Nombre, p.Descuento, p.Descripcion,
             p.FechaInicio, p.FechaFin, p.TipoPromocion;
END;
GO

-- 17. Resolver solicitudes especiales
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ResolverSolicitudEspecial
    @SolicitudID INT,
    @Estado      VARCHAR(20),
    @EmpleadoID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        UPDATE Agenda.SolicitudEspecial
        SET Estado = @Estado
        WHERE SolicitudID = @SolicitudID;

        IF @Estado = 'aprobada'
        BEGIN
            DECLARE @ClienteID   INT;
            DECLARE @FechaInicio DATETIME;
            DECLARE @ServicioIDs VARCHAR(500);

            SELECT 
                @ClienteID   = ClienteID,
                @FechaInicio = FechaSolicitada,
                @ServicioIDs = ServicioIDs
            FROM Agenda.SolicitudEspecial
            WHERE SolicitudID = @SolicitudID;

            -- Tomar el primer ServicioID
            DECLARE @ServicioID INT = CAST(LEFT(@ServicioIDs, CHARINDEX(',', @ServicioIDs + ',') - 1) AS INT);

            -- Crear la cita
            DECLARE @CitaID INT;
            INSERT INTO Agenda.Cita (ClienteID, FechaInicio, EstadoID)
            VALUES (@ClienteID, @FechaInicio, 8);
            SET @CitaID = SCOPE_IDENTITY();

            -- Asignación de empleado
            DECLARE @EmpAsignado INT = @EmpleadoID;

            IF @EmpAsignado IS NULL
            BEGIN
                DECLARE @SubcatID INT;
                SELECT @SubcatID = SubcategoriaID FROM Servicios.Servicio WHERE ServicioID = @ServicioID;

                SELECT TOP 1 @EmpAsignado = e.EmpleadoID
                FROM RRHH.Empleado e
                JOIN RRHH.EmpleadoRol er ON er.EmpleadoID = e.EmpleadoID
                JOIN Servicios.SubcategoriaRol sr ON sr.RolID = er.RolID
                WHERE sr.SubcategoriaID = @SubcatID
                  AND e.Activo = 1
                  AND er.RolID IN (3,4,5,6)
                ORDER BY NEWID();
            END

            DECLARE @Duracion INT;
            SELECT @Duracion = DuracionMin FROM Servicios.Servicio WHERE ServicioID = @ServicioID;

            DECLARE @FechaFin DATETIME = DATEADD(MINUTE, @Duracion, @FechaInicio);

            INSERT INTO Agenda.CitaServicio
                (CitaID, ServicioID, EmpleadoID, Orden, EsParalelo, FechaInicioServicio, FechaFinServicio)
            VALUES
                (@CitaID, @ServicioID, @EmpAsignado, 1, 0, @FechaInicio, @FechaFin);

            INSERT INTO Agenda.CitaEmpleado (CitaID, EmpleadoID, TipoAsignacion)
            VALUES (@CitaID, @EmpAsignado, CASE WHEN @EmpleadoID IS NOT NULL THEN 'manual' ELSE 'automatica' END);

            -- Actualizar CitaID en la solicitud
            UPDATE Agenda.SolicitudEspecial
            SET CitaID = @CitaID
            WHERE SolicitudID = @SolicitudID;
        END

        COMMIT;
        SELECT 'Solicitud actualizada.' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @Error VARCHAR(500) = ERROR_MESSAGE();
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO

-- 18. Registrar ventas
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_RegistrarVenta
    @ClienteID      INT,
    @EmpleadoID     INT          = NULL,
    @MetodoPagoID   INT,
    @Monto          DECIMAL(10,2),
    @Referencia     VARCHAR(100) = NULL,
    @Servicios      VARCHAR(MAX) = NULL,
    @Productos      VARCHAR(MAX) = NULL,
    @DescuentoPct   DECIMAL(5,2) = 0,
    @PromocionID    INT          = NULL,
    @DescuentoMonto DECIMAL(10,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF @Servicios IS NULL AND @Productos IS NULL
        BEGIN ROLLBACK; RAISERROR('Debe incluir al menos un servicio o producto.',16,1); RETURN; END

        DECLARE @VentaID INT;
        INSERT INTO Ventas.Venta (ClienteID, EmpleadoID, Estado, DescuentoPct, DescuentoMonto, PromocionID)
        VALUES (@ClienteID, @EmpleadoID, 'pendiente', @DescuentoPct, @DescuentoMonto, @PromocionID);
        SET @VentaID = SCOPE_IDENTITY();

        IF @Servicios IS NOT NULL
        BEGIN
            DECLARE @SrvList VARCHAR(MAX) = @Servicios + ',';
            DECLARE @SrvPos  INT = 1, @SrvNext INT;
            DECLARE @SrvItem VARCHAR(200);
            DECLARE @P1 VARCHAR(50), @P2 VARCHAR(50), @P3 VARCHAR(50), @P4 VARCHAR(50);
            DECLARE @SrvID INT, @SrvQty INT, @SrvPrice DECIMAL(10,2), @SrvEmpID INT;

            WHILE CHARINDEX(',',@SrvList,@SrvPos) > 0
            BEGIN
                SET @SrvNext = CHARINDEX(',',@SrvList,@SrvPos);
                SET @SrvItem = SUBSTRING(@SrvList,@SrvPos,@SrvNext-@SrvPos);
                SET @P1 = SUBSTRING(@SrvItem,1,CHARINDEX(':',@SrvItem)-1);
                SET @SrvItem = SUBSTRING(@SrvItem,CHARINDEX(':',@SrvItem)+1,LEN(@SrvItem));
                SET @P2 = SUBSTRING(@SrvItem,1,CHARINDEX(':',@SrvItem)-1);
                SET @SrvItem = SUBSTRING(@SrvItem,CHARINDEX(':',@SrvItem)+1,LEN(@SrvItem));
                SET @P3 = SUBSTRING(@SrvItem,1,CHARINDEX(':',@SrvItem)-1);
                SET @P4 = SUBSTRING(@SrvItem,CHARINDEX(':',@SrvItem)+1,LEN(@SrvItem));
                SET @SrvID    = CAST(@P1 AS INT);
                SET @SrvQty   = CAST(@P2 AS INT);
                SET @SrvPrice = CAST(@P3 AS DECIMAL(10,2));
                SET @SrvEmpID = CASE WHEN ISNUMERIC(@P4)=1 AND CAST(@P4 AS INT)>0 THEN CAST(@P4 AS INT) ELSE NULL END;

                INSERT INTO Ventas.VentaDetalleServicio(VentaID,ServicioID,Cantidad,PrecioUnitario,EmpleadoID)
                VALUES(@VentaID,@SrvID,@SrvQty,@SrvPrice,@SrvEmpID);
                SET @SrvPos = @SrvNext + 1;
            END
        END

        IF @Productos IS NOT NULL
        BEGIN
            DECLARE @PrdList VARCHAR(MAX)=@Productos+',';
            DECLARE @PrdPos INT=1,@PrdNext INT;
            DECLARE @PrdItem VARCHAR(200);
            DECLARE @Q1 VARCHAR(50),@Q2 VARCHAR(50),@Q3 VARCHAR(50);
            DECLARE @PrdID INT,@PrdQty INT,@PrdPrice DECIMAL(10,2);

            WHILE CHARINDEX(',',@PrdList,@PrdPos)>0
            BEGIN
                SET @PrdNext=CHARINDEX(',',@PrdList,@PrdPos);
                SET @PrdItem=SUBSTRING(@PrdList,@PrdPos,@PrdNext-@PrdPos);
                SET @Q1=SUBSTRING(@PrdItem,1,CHARINDEX(':',@PrdItem)-1);
                SET @PrdItem=SUBSTRING(@PrdItem,CHARINDEX(':',@PrdItem)+1,LEN(@PrdItem));
                SET @Q2=SUBSTRING(@PrdItem,1,CHARINDEX(':',@PrdItem)-1);
                SET @Q3=SUBSTRING(@PrdItem,CHARINDEX(':',@PrdItem)+1,LEN(@PrdItem));
                SET @PrdID=CAST(@Q1 AS INT);
                SET @PrdQty=CAST(@Q2 AS INT);
                SET @PrdPrice=CAST(@Q3 AS DECIMAL(10,2));
                INSERT INTO Ventas.VentaDetalleProducto(VentaID,ProductoID,Cantidad,PrecioUnitario)
                VALUES(@VentaID,@PrdID,@PrdQty,@PrdPrice);
                UPDATE Inventario.Producto SET StockActual=StockActual-@PrdQty WHERE ProductoID=@PrdID;
                INSERT INTO Inventario.MovimientoInventario(ProductoID,EsEntrada,Cantidad) VALUES(@PrdID,0,@PrdQty);
                SET @PrdPos=@PrdNext+1;
            END
        END

        UPDATE Ventas.Venta SET Estado='pagado' WHERE VentaID=@VentaID;

        DECLARE @NumeroFactura VARCHAR(50)='COCO-SC-'+RIGHT('0000'+CAST(@VentaID AS VARCHAR),4);
        DECLARE @FacturaID INT;
        INSERT INTO Facturacion.Factura(VentaID,NumeroFactura,Estado) VALUES(@VentaID,@NumeroFactura,'emitida');
        SET @FacturaID=SCOPE_IDENTITY();
        INSERT INTO Ventas.Pago(VentaID,MetodoPagoID,Monto) VALUES(@VentaID,@MetodoPagoID,@Monto);
        UPDATE Facturacion.Factura SET Estado='pagada' WHERE FacturaID=@FacturaID;

        COMMIT;
        SELECT @VentaID AS VentaID, @NumeroFactura AS NumeroFactura,
               @Monto AS Total, 'Venta registrada y factura generada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @ErrMsg VARCHAR(500)=ERROR_MESSAGE();
        RAISERROR(@ErrMsg,16,1);
    END CATCH
END;
GO

-- 19. Completar citas
USE SalonBelleza_DB;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_CompletarCita
    @CitaID     INT,
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        IF NOT EXISTS (
            SELECT 1 FROM Agenda.CitaServicio
            WHERE CitaID = @CitaID AND EmpleadoID = @EmpleadoID
        )
        BEGIN
            ROLLBACK;
            RAISERROR('No tienes permiso para completar esta cita.', 16, 1);
            RETURN;
        END

        UPDATE Agenda.Cita SET EstadoID = 11 WHERE CitaID = @CitaID;

        COMMIT;

        SET NOCOUNT OFF;

        SELECT
            c.CitaID,
            cl.ClienteID,
            p.Nombre        AS NombreCliente,
            p.Apellido      AS ApellidoCliente,
            p.Email         AS EmailCliente,
            s.Nombre        AS Servicio,
            s.DuracionMin,
            pe.Nombre       AS NombreEmpleado,
            pe.Apellido     AS ApellidoEmpleado,
            sp.Precio       AS Total,
            cd.NotasTecnicas
        FROM Agenda.Cita c
        JOIN Ventas.Cliente cl ON cl.ClienteID = c.ClienteID
        JOIN Personas.Persona p ON p.PersonaID = cl.ClienteID
        JOIN Agenda.CitaServicio cs ON cs.CitaID = c.CitaID AND cs.EmpleadoID = @EmpleadoID
        JOIN Servicios.Servicio s ON s.ServicioID = cs.ServicioID
        JOIN Personas.Persona pe ON pe.PersonaID = @EmpleadoID
        LEFT JOIN Servicios.ServicioPrecio sp ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
        LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID = cl.ClienteID
        WHERE c.CitaID = @CitaID;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR('Error al completar la cita.', 16, 1);
    END CATCH
END;
GO