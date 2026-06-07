-- COCO Salón de Belleza · SalonBelleza_DB
-- 14 · STORED PROCEDURES · MÓDULO PERSONAL TÉCNICO

USE SalonBelleza_DB;
GO

-- 1. Agenda del día
--    RS[0] Estadísticas del día  RS[1] Timeline del día
--    RS[2] Resumen de la semana  RS[3] Citas de la semana completa
--    Fechas devueltas como NVARCHAR(19) para evitar conversión UTC
--    Comisiones calculadas desde Ventas.VentaDetalleServicio
CREATE OR ALTER PROCEDURE Agenda.SP_AgendaDelDia
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(*)                                          AS TotalCitas,
        SUM(CASE WHEN c.EstadoID = 9  THEN 1 ELSE 0 END) AS Confirmadas,
        SUM(CASE WHEN c.EstadoID = 8  THEN 1 ELSE 0 END) AS Pendientes,
        SUM(CASE WHEN c.EstadoID = 11 THEN 1 ELSE 0 END) AS Completadas,
        ISNULL((
            SELECT SUM(vds.PrecioUnitario * vds.Cantidad)
            FROM Ventas.VentaDetalleServicio vds
            JOIN Ventas.Venta v ON v.VentaID = vds.VentaID
            WHERE vds.EmpleadoID = @EmpleadoID
              AND CAST(v.Fecha AS DATE) = CAST(GETDATE() AS DATE)
        ), 0) AS IngresosDia,
        ISNULL((
            SELECT SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0)
            FROM Ventas.VentaDetalleServicio vds
            JOIN Ventas.Venta v ON v.VentaID = vds.VentaID
            JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID = vds.EmpleadoID AND ec.FechaFin IS NULL
            WHERE vds.EmpleadoID = @EmpleadoID
              AND CAST(v.Fecha AS DATE) = CAST(GETDATE() AS DATE)
        ), 0) AS ComisionDia
    FROM Agenda.CitaServicio cs
    JOIN Agenda.Cita         c ON c.CitaID = cs.CitaID
    WHERE cs.EmpleadoID = @EmpleadoID
      AND CAST(cs.FechaInicioServicio AS DATE) = CAST(GETDATE() AS DATE)
      AND c.EstadoID NOT IN (12, 13);

    SELECT
        c.CitaID, c.ClienteID,
        p.Nombre  AS NombreCliente, p.Apellido AS ApellidoCliente,
        s.ServicioID, s.Nombre AS Servicio,
        CONVERT(NVARCHAR(19), cs.FechaInicioServicio, 120) AS FechaInicioServicio,
        CONVERT(NVARCHAR(19), cs.FechaFinServicio,    120) AS FechaFinServicio,
        ec.EstadoID, ec.Nombre AS Estado,
        sp.Precio,
        cd.Alergias, cd.Contraindicaciones
    FROM Agenda.CitaServicio        cs
    JOIN Agenda.Cita                c  ON c.CitaID      = cs.CitaID
    JOIN Personas.Persona           p  ON p.PersonaID   = c.ClienteID
    JOIN Servicios.Servicio         s  ON s.ServicioID  = cs.ServicioID
    JOIN Agenda.EstadoCita          ec ON ec.EstadoID   = c.EstadoID
    JOIN Servicios.ServicioPrecio   sp ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
    LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID  = c.ClienteID
    WHERE cs.EmpleadoID = @EmpleadoID
      AND CAST(cs.FechaInicioServicio AS DATE) = CAST(GETDATE() AS DATE)
      AND c.EstadoID NOT IN (12, 13)
    ORDER BY cs.FechaInicioServicio ASC;

    SELECT
        (SELECT COUNT(DISTINCT cs2.CitaID)
         FROM Agenda.CitaServicio cs2
         JOIN Agenda.Cita c2 ON c2.CitaID = cs2.CitaID
         WHERE cs2.EmpleadoID = @EmpleadoID
           AND DATEPART(WEEK, cs2.FechaInicioServicio) = DATEPART(WEEK, GETDATE())
           AND YEAR(cs2.FechaInicioServicio) = YEAR(GETDATE())
           AND c2.EstadoID NOT IN (12, 13))                AS CitasSemana,
        ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad), 0)  AS IngresosSemana,
        ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec2.Porcentaje / 100.0), 0) AS ComisionesSemana
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta                v   ON v.VentaID      = vds.VentaID
    JOIN RRHH.EmpleadoComision       ec2 ON ec2.EmpleadoID = vds.EmpleadoID AND ec2.FechaFin IS NULL
    WHERE vds.EmpleadoID = @EmpleadoID
      AND DATEPART(WEEK, v.Fecha) = DATEPART(WEEK, GETDATE())
      AND YEAR(v.Fecha)           = YEAR(GETDATE());

    SELECT
        c.CitaID, c.ClienteID,
        p.Nombre  AS NombreCliente, p.Apellido AS ApellidoCliente,
        s.Nombre  AS Servicio,
        CONVERT(NVARCHAR(19), cs.FechaInicioServicio, 120) AS FechaInicioServicio,
        CONVERT(NVARCHAR(19), cs.FechaFinServicio,    120) AS FechaFinServicio,
        ec.Nombre AS Estado, ec.EstadoID,
        sp.Precio
    FROM Agenda.CitaServicio      cs
    JOIN Agenda.Cita              c  ON c.CitaID      = cs.CitaID
    JOIN Personas.Persona         p  ON p.PersonaID   = c.ClienteID
    JOIN Servicios.Servicio       s  ON s.ServicioID  = cs.ServicioID
    JOIN Agenda.EstadoCita        ec ON ec.EstadoID   = c.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
    WHERE cs.EmpleadoID = @EmpleadoID
      AND DATEPART(WEEK, cs.FechaInicioServicio) = DATEPART(WEEK, GETDATE())
      AND YEAR(cs.FechaInicioServicio)           = YEAR(GETDATE())
      AND c.EstadoID NOT IN (12, 13)
    ORDER BY cs.FechaInicioServicio ASC;
END;
GO

-- 2. Horario semanal del empleado
--    RS[0] Horario fijo  RS[1] Excepciones
--    Fechas de excepciones como NVARCHAR(10) para evitar conversión UTC
CREATE OR ALTER PROCEDURE RRHH.SP_ObtenerHorarioEmpleado
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DiaSemana, HoraEntrada, HoraSalida, Activo
    FROM RRHH.HorarioEmpleado
    WHERE EmpleadoID = @EmpleadoID
    ORDER BY DiaSemana;

    SELECT ExcepcionID,
           CONVERT(NVARCHAR(10), Fecha, 120) AS Fecha,
           Disponible, Motivo,
           ISNULL(Estado, 'Pendiente') AS Estado,
           Aprobado
    FROM RRHH.HorarioExcepcion
    WHERE EmpleadoID = @EmpleadoID
    ORDER BY Fecha DESC;
END;
GO

-- 3. Solicitar excepción de horario
--    Aprobado = NULL al crear (pendiente de revisión)
CREATE OR ALTER PROCEDURE RRHH.SP_SolicitarExcepcion
    @EmpleadoID INT,
    @Fecha      DATE,
    @Disponible BIT,
    @Motivo     VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM RRHH.HorarioExcepcion WHERE EmpleadoID = @EmpleadoID AND Fecha = @Fecha)
    BEGIN RAISERROR('Ya existe una solicitud para esa fecha.', 16, 1); RETURN; END

    INSERT INTO RRHH.HorarioExcepcion (EmpleadoID, Fecha, Disponible, Motivo, Aprobado, Estado, TipoSolicitud)
    VALUES (@EmpleadoID, @Fecha, @Disponible, @Motivo, NULL, 'Pendiente', 'empleado');

    SELECT SCOPE_IDENTITY() AS ExcepcionID, 'Solicitud enviada correctamente.' AS Mensaje;
END;
GO

-- 4. Mis clientes
--    RS[0] Clientes únicos  RS[1] Distribución por subcategoría
--    RS[2] Tasa de retención
--    Basado en citas completadas (EstadoID = 11)
CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerClientesEmpleado
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        p.PersonaID     AS ClienteID,
        p.Nombre, p.Apellido, p.Telefono, p.Email,
        cd.Alergias, cd.Contraindicaciones, cd.NotasTecnicas,
        COUNT(c.CitaID) OVER (PARTITION BY c.ClienteID)              AS TotalVisitas,
        MAX(cs.FechaInicioServicio) OVER (PARTITION BY c.ClienteID)  AS UltimaVisita
    FROM Agenda.CitaServicio        cs
    JOIN Agenda.Cita                c  ON c.CitaID     = cs.CitaID
    JOIN Personas.Persona           p  ON p.PersonaID  = c.ClienteID
    LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID = c.ClienteID
    WHERE cs.EmpleadoID = @EmpleadoID AND c.EstadoID = 11
    ORDER BY UltimaVisita DESC;

    SELECT
        sc.Nombre AS Subcategoria,
        COUNT(*)  AS TotalServicios,
        CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS Porcentaje
    FROM Agenda.CitaServicio            cs
    JOIN Agenda.Cita                    c  ON c.CitaID          = cs.CitaID
    JOIN Servicios.Servicio             s  ON s.ServicioID       = cs.ServicioID
    JOIN Servicios.SubcategoriaServicio sc ON sc.SubcategoriaID  = s.SubcategoriaID
    WHERE cs.EmpleadoID = @EmpleadoID AND c.EstadoID = 11
    GROUP BY sc.SubcategoriaID, sc.Nombre
    ORDER BY TotalServicios DESC;

    SELECT
        COUNT(DISTINCT sub.ClienteID) AS TotalClientes,
        SUM(CASE WHEN sub.visitas > 1 THEN 1 ELSE 0 END) AS ClientesRecurrentes,
        CAST(SUM(CASE WHEN sub.visitas > 1 THEN 1 ELSE 0 END) * 100.0 /
             NULLIF(COUNT(DISTINCT sub.ClienteID), 0) AS DECIMAL(5,2)) AS PorcentajeRetencion
    FROM (
        SELECT c.ClienteID, COUNT(*) AS visitas
        FROM Agenda.CitaServicio cs
        JOIN Agenda.Cita c ON c.CitaID = cs.CitaID
        WHERE cs.EmpleadoID = @EmpleadoID AND c.EstadoID = 11
        GROUP BY c.ClienteID
    ) sub;
END;
GO

-- 5. Ficha de cliente
--    RS[0] Datos del cliente  RS[1] Historial con este empleado
--    RS[2] Cita actual (en curso o confirmada hoy)
CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerFichaCliente
    @ClienteID  INT,
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.PersonaID, p.Nombre, p.Apellido, p.Telefono, p.Email, p.FechaRegistro,
           cd.Alergias, cd.Contraindicaciones, cd.NotasTecnicas,
           COUNT(c.CitaID) AS TotalVisitas
    FROM Personas.Persona           p
    JOIN Ventas.Cliente              cl ON cl.ClienteID  = p.PersonaID
    LEFT JOIN Ventas.ClienteDetalle  cd ON cd.ClienteID  = p.PersonaID
    LEFT JOIN Agenda.Cita            c  ON c.ClienteID   = p.PersonaID AND c.EstadoID = 11
    WHERE p.PersonaID = @ClienteID
    GROUP BY p.PersonaID, p.Nombre, p.Apellido, p.Telefono,
             p.Email, p.FechaRegistro, cd.Alergias, cd.Contraindicaciones, cd.NotasTecnicas;

    SELECT c.CitaID, cs.FechaInicioServicio, s.Nombre AS Servicio,
           ec.Nombre AS Estado, sp.Precio
    FROM Agenda.CitaServicio      cs
    JOIN Agenda.Cita              c  ON c.CitaID     = cs.CitaID
    JOIN Servicios.Servicio       s  ON s.ServicioID = cs.ServicioID
    JOIN Agenda.EstadoCita        ec ON ec.EstadoID  = c.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
    WHERE c.ClienteID   = @ClienteID AND cs.EmpleadoID = @EmpleadoID
    ORDER BY cs.FechaInicioServicio DESC;

    SELECT TOP 1
        c.CitaID, cs.FechaInicioServicio, cs.FechaFinServicio,
        s.Nombre AS Servicio, s.DuracionMin, sp.Precio,
        ec.Nombre AS Estado, ec.EstadoID
    FROM Agenda.CitaServicio      cs
    JOIN Agenda.Cita              c  ON c.CitaID     = cs.CitaID
    JOIN Servicios.Servicio       s  ON s.ServicioID = cs.ServicioID
    JOIN Agenda.EstadoCita        ec ON ec.EstadoID  = c.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
    WHERE c.ClienteID   = @ClienteID AND cs.EmpleadoID = @EmpleadoID
      AND c.EstadoID IN (9, 10)
      AND CAST(cs.FechaInicioServicio AS DATE) = CAST(GETDATE() AS DATE)
    ORDER BY cs.FechaInicioServicio ASC;
END;
GO

-- 6. Actualizar notas técnicas del cliente
CREATE OR ALTER PROCEDURE Ventas.SP_ActualizarNotasTecnicas
    @ClienteID     INT,
    @NotasTecnicas VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Ventas.ClienteDetalle WHERE ClienteID = @ClienteID)
            UPDATE Ventas.ClienteDetalle SET NotasTecnicas = @NotasTecnicas WHERE ClienteID = @ClienteID;
        ELSE
            INSERT INTO Ventas.ClienteDetalle (ClienteID, NotasTecnicas) VALUES (@ClienteID, @NotasTecnicas);
        COMMIT;
        SELECT 'Notas actualizadas correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR('Error al actualizar notas.', 16, 1);
    END CATCH
END;
GO

-- 7. Marcar cita como completada
CREATE OR ALTER PROCEDURE Agenda.SP_CompletarCita
    @CitaID     INT,
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Agenda.CitaServicio WHERE CitaID = @CitaID AND EmpleadoID = @EmpleadoID)
        BEGIN ROLLBACK; RAISERROR('No tienes permiso para completar esta cita.', 16, 1); RETURN; END

        UPDATE Agenda.Cita SET EstadoID = 11 WHERE CitaID = @CitaID;
        COMMIT;
        SELECT 'Cita marcada como completada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR('Error al completar la cita.', 16, 1);
    END CATCH
END;
GO

-- 8. Sueldo y comisiones
--    RS[0] Vigentes  RS[1] Mes actual  RS[2] Semanas del mes
--    RS[3] Últimos 4 meses
--    Comisiones calculadas desde VentaDetalleServicio
CREATE OR ALTER PROCEDURE RRHH.SP_ObtenerSueldoComisiones
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT es.SueldoBase, es.FechaInicio AS SueldoDesde,
           ec.Porcentaje AS PorcentajeComision, ec.FechaInicio AS ComisionDesde
    FROM RRHH.EmpleadoSueldo   es
    JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID = es.EmpleadoID AND ec.FechaFin IS NULL
    WHERE es.EmpleadoID = @EmpleadoID AND es.FechaFin IS NULL;

    SELECT
        ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad), 0) AS VentasMes,
        ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0), 0) AS ComisionMes,
        COUNT(DISTINCT vds.VentaDetalleServicioID) AS ServiciosMes
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta                v  ON v.VentaID     = vds.VentaID
    JOIN RRHH.EmpleadoComision       ec ON ec.EmpleadoID = vds.EmpleadoID AND ec.FechaFin IS NULL
    WHERE vds.EmpleadoID = @EmpleadoID
      AND MONTH(v.Fecha) = MONTH(GETDATE()) AND YEAR(v.Fecha) = YEAR(GETDATE());

    SELECT
        DATEPART(WEEK, v.Fecha) -
        DATEPART(WEEK, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)) + 1 AS Semana,
        ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0), 0) AS ComisionSemana
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta                v  ON v.VentaID     = vds.VentaID
    JOIN RRHH.EmpleadoComision       ec ON ec.EmpleadoID = vds.EmpleadoID AND ec.FechaFin IS NULL
    WHERE vds.EmpleadoID = @EmpleadoID
      AND MONTH(v.Fecha) = MONTH(GETDATE()) AND YEAR(v.Fecha) = YEAR(GETDATE())
    GROUP BY DATEPART(WEEK, v.Fecha) -
             DATEPART(WEEK, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)) + 1
    ORDER BY Semana;

    SELECT TOP 4
        YEAR(v.Fecha) AS Anio, MONTH(v.Fecha) AS Mes,
        ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad), 0) AS Ventas,
        ISNULL(SUM(vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0), 0) AS Comision,
        es.SueldoBase
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta                v  ON v.VentaID     = vds.VentaID
    JOIN RRHH.EmpleadoComision       ec ON ec.EmpleadoID = vds.EmpleadoID AND ec.FechaFin IS NULL
    JOIN RRHH.EmpleadoSueldo         es ON es.EmpleadoID = vds.EmpleadoID AND es.FechaFin IS NULL
    WHERE vds.EmpleadoID = @EmpleadoID
    GROUP BY YEAR(v.Fecha), MONTH(v.Fecha), es.SueldoBase
    ORDER BY Anio DESC, Mes DESC;
END;
GO

-- 9. Mis ventas
CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerVentasEmpleado
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.Fecha, p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
           s.Nombre AS Servicio, 'Servicio' AS Tipo,
           vds.PrecioUnitario AS Precio,
           vds.PrecioUnitario * vds.Cantidad * ec.Porcentaje / 100.0 AS Comision
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta                v  ON v.VentaID    = vds.VentaID
    JOIN Personas.Persona            p  ON p.PersonaID  = v.ClienteID
    JOIN Servicios.Servicio          s  ON s.ServicioID = vds.ServicioID
    JOIN RRHH.EmpleadoComision       ec ON ec.EmpleadoID = vds.EmpleadoID AND ec.FechaFin IS NULL
    WHERE vds.EmpleadoID = @EmpleadoID
    ORDER BY v.Fecha DESC;
END;
GO

-- 10. Perfil del empleado
CREATE OR ALTER PROCEDURE RRHH.SP_ObtenerPerfilEmpleado
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PersonaID, p.Nombre, p.Apellido, p.Email, p.Telefono,
           e.FechaContratacion, r.NombreRol,
           es.SueldoBase, es.FechaInicio AS SueldoDesde,
           ec.Porcentaje AS PorcentajeComision, ec.FechaInicio AS ComisionDesde
    FROM Personas.Persona        p
    JOIN RRHH.Empleado           e  ON e.EmpleadoID  = p.PersonaID
    JOIN RRHH.EmpleadoRol        er ON er.EmpleadoID = p.PersonaID
    JOIN RRHH.Rol                r  ON r.RolID       = er.RolID
    JOIN RRHH.EmpleadoSueldo     es ON es.EmpleadoID = p.PersonaID AND es.FechaFin IS NULL
    JOIN RRHH.EmpleadoComision   ec ON ec.EmpleadoID = p.PersonaID AND ec.FechaFin IS NULL
    WHERE p.PersonaID = @EmpleadoID;
END;
GO

-- 11. Actualizar perfil del empleado
CREATE OR ALTER PROCEDURE RRHH.SP_ActualizarPerfilEmpleado
    @EmpleadoID INT,
    @Nombre     VARCHAR(100),
    @Apellido   VARCHAR(100),
    @Telefono   VARCHAR(20),
    @Email      VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email = @Email AND PersonaID <> @EmpleadoID)
    BEGIN RAISERROR('Este correo ya está en uso.', 16, 1); RETURN; END
    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Telefono = @Telefono AND PersonaID <> @EmpleadoID)
    BEGIN RAISERROR('Este teléfono ya está en uso.', 16, 1); RETURN; END

    UPDATE Personas.Persona
    SET Nombre = @Nombre, Apellido = @Apellido, Telefono = @Telefono, Email = @Email
    WHERE PersonaID = @EmpleadoID;

    UPDATE Seguridad.Usuario SET Username = @Email WHERE PersonaID = @EmpleadoID;
    SELECT 'Perfil actualizado correctamente.' AS Mensaje;
END;
GO