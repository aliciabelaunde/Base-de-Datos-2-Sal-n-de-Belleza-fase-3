-- COCO Salón de Belleza · SalonBelleza_DB
-- 08 · TABLAS · MÓDULO AGENDA

USE SalonBelleza_DB;
GO

-- 1. EstadoCita
--    IDs reales: 8=Programada 9=Confirmada 10=En curso
--                11=Completada 12=Cancelada  13=No asistió
CREATE TABLE Agenda.EstadoCita (
    EstadoID INT         IDENTITY PRIMARY KEY,
    Nombre   VARCHAR(50) NOT NULL UNIQUE
);

-- 2. Cita
CREATE TABLE Agenda.Cita (
    CitaID      INT      IDENTITY PRIMARY KEY,
    ClienteID   INT      NOT NULL,
    FechaInicio DATETIME NOT NULL,
    EstadoID    INT      NOT NULL,
    FOREIGN KEY (ClienteID) REFERENCES Ventas.Cliente(ClienteID),
    FOREIGN KEY (EstadoID)  REFERENCES Agenda.EstadoCita(EstadoID)
);

-- 3. CitaServicio
--    Detalle de servicios por cita con horarios individuales y opción paralela
CREATE TABLE Agenda.CitaServicio (
    CitaServicioID      INT      IDENTITY PRIMARY KEY,
    CitaID              INT      NOT NULL,
    ServicioID          INT      NOT NULL,
    EmpleadoID          INT      NULL,
    Orden               INT      NOT NULL DEFAULT 1,
    EsParalelo          BIT      NOT NULL DEFAULT 0,
    FechaInicioServicio DATETIME NULL,
    FechaFinServicio    DATETIME NULL,
    FOREIGN KEY (CitaID)     REFERENCES Agenda.Cita(CitaID),
    FOREIGN KEY (ServicioID) REFERENCES Servicios.Servicio(ServicioID),
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID)
);

-- 4. CitaEmpleado
--    TipoAsignacion: 'manual' (elegido por cliente/recepción) | 'automatica'
CREATE TABLE Agenda.CitaEmpleado (
    CitaEmpleadoID INT         IDENTITY PRIMARY KEY,
    CitaID         INT         NOT NULL,
    EmpleadoID     INT         NULL,
    TipoAsignacion VARCHAR(10) NOT NULL DEFAULT 'manual'
                   CHECK (TipoAsignacion IN ('manual','automatica')),
    FOREIGN KEY (CitaID)     REFERENCES Agenda.Cita(CitaID),
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID)
);

-- 5. SolicitudEspecial
--    Peticiones de horario fuera del rango normal (antes 9am, después 7pm, domingos)
--    TipoSolicitud: 'antes_9am' | 'despues_7pm' | 'domingo'
--    Estado: 'Pendiente' | 'Aprobada' | 'Rechazada'
CREATE TABLE Agenda.SolicitudEspecial (
    SolicitudID     INT          IDENTITY PRIMARY KEY,
    ClienteID       INT          NOT NULL,
    FechaSolicitada DATETIME     NOT NULL,
    Motivo          VARCHAR(200),
    Estado          VARCHAR(20)  NOT NULL DEFAULT 'Pendiente',
    FechaCreacion   DATETIME     NOT NULL DEFAULT GETDATE(),
    TipoSolicitud   VARCHAR(30)  NULL,
    ServicioIDs     VARCHAR(500) NULL,
    MotivoRechazo   VARCHAR(300) NULL,
    CitaID          INT          NULL,
    FOREIGN KEY (ClienteID) REFERENCES Ventas.Cliente(ClienteID)
);