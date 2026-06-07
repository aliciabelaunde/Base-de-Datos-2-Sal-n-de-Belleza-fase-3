-- COCO Salón de Belleza · SalonBelleza_DB
-- 03 · TABLAS · MÓDULO RRHH

USE SalonBelleza_DB;
GO

-- 1. Rol laboral
CREATE TABLE RRHH.Rol (
    RolID     INT          IDENTITY(1,1) PRIMARY KEY,
    NombreRol VARCHAR(50)  NOT NULL UNIQUE
);

-- 2. Empleado
--    Extiende Personas.Persona con datos contractuales
CREATE TABLE RRHH.Empleado (
    EmpleadoID        INT  PRIMARY KEY,
    FechaContratacion DATE NOT NULL DEFAULT GETDATE(),
    Activo            BIT  NOT NULL DEFAULT 1,
    CONSTRAINT FK_Empleado_Persona
        FOREIGN KEY (EmpleadoID) REFERENCES Personas.Persona(PersonaID)
);

-- 3. EmpleadoRol
--    Relación muchos-a-muchos entre empleados y roles laborales
CREATE TABLE RRHH.EmpleadoRol (
    EmpleadoID INT NOT NULL,
    RolID      INT NOT NULL,
    PRIMARY KEY (EmpleadoID, RolID),
    CONSTRAINT FK_EmpRol_Empleado FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID),
    CONSTRAINT FK_EmpRol_Rol      FOREIGN KEY (RolID)      REFERENCES RRHH.Rol(RolID)
);

-- 4. EmpleadoSueldo
--    Historial de sueldos base (FechaFin = NULL → vigente)
CREATE TABLE RRHH.EmpleadoSueldo (
    EmpleadoSueldoID INT           IDENTITY PRIMARY KEY,
    EmpleadoID       INT           NOT NULL,
    SueldoBase       DECIMAL(10,2) NOT NULL CHECK (SueldoBase > 0),
    FechaInicio      DATE          NOT NULL,
    FechaFin         DATE          NULL,
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID)
);
GO

-- Ajuste: permite FechaFin = FechaInicio para cierres en el mismo día
ALTER TABLE RRHH.EmpleadoSueldo
    ADD CONSTRAINT CK_EmpleadoSueldo_Fechas
    CHECK (FechaFin IS NULL OR FechaFin >= FechaInicio);
GO

-- 5. EmpleadoComision
--    Historial de porcentajes de comisión (FechaFin = NULL → vigente)
CREATE TABLE RRHH.EmpleadoComision (
    EmpleadoComisionID INT          IDENTITY PRIMARY KEY,
    EmpleadoID         INT          NOT NULL,
    Porcentaje         DECIMAL(5,2) NOT NULL CHECK (Porcentaje >= 0 AND Porcentaje <= 100),
    FechaInicio        DATE         NOT NULL,
    FechaFin           DATE         NULL,
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID),
    CHECK (FechaFin IS NULL OR FechaFin > FechaInicio)
);

-- 6. HorarioEmpleado
--    Horario fijo semanal por empleado (DiaSemana: 1=Lunes … 7=Domingo)
CREATE TABLE RRHH.HorarioEmpleado (
    HorarioID   INT     IDENTITY PRIMARY KEY,
    EmpleadoID  INT     NOT NULL,
    DiaSemana   TINYINT NOT NULL CHECK (DiaSemana BETWEEN 1 AND 7),
    HoraEntrada TIME    NOT NULL,
    HoraSalida  TIME    NOT NULL,
    Activo      BIT     NOT NULL DEFAULT 1,
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID),
    CHECK (HoraSalida > HoraEntrada)
);

-- 7. HorarioExcepcion
--    Días libres y turnos extra solicitados por el personal
--    Disponible: 0 = día libre · 1 = turno extra
--    Estado:     Pendiente / Aprobada / Rechazada
CREATE TABLE RRHH.HorarioExcepcion (
    ExcepcionID   INT          IDENTITY PRIMARY KEY,
    EmpleadoID    INT          NOT NULL,
    Fecha         DATE         NOT NULL,
    Disponible    BIT          NOT NULL DEFAULT 0,
    Motivo        VARCHAR(200),
    Aprobado      BIT          NULL,
    Estado        VARCHAR(20)  NULL,
    TipoSolicitud VARCHAR(10)  NOT NULL DEFAULT 'empleado'
                  CHECK (TipoSolicitud IN ('empleado','cliente')),
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID)
);

-- 8. PagoNomina
--    Registro de pagos mensuales de nómina
--    Total es columna calculada: SueldoBase + Comision
CREATE TABLE RRHH.PagoNomina (
    PagoNominaID INT           IDENTITY PRIMARY KEY,
    EmpleadoID   INT           NOT NULL,
    Periodo      VARCHAR(7)    NOT NULL,   -- formato: 'AAAA-MM'
    SueldoBase   DECIMAL(10,2) NOT NULL,
    Comision     DECIMAL(10,2) NOT NULL DEFAULT 0,
    Total        AS (SueldoBase + Comision),
    FechaPago    DATETIME      NULL,
    Pagado       BIT           NOT NULL DEFAULT 0,
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID)
);
GO

-- Ajuste posterior: EmpleadoID en Ventas.Venta puede ser NULL
--   (ventas de solo productos no requieren personal)
ALTER TABLE Ventas.Venta
    ALTER COLUMN EmpleadoID INT NULL;
GO