-- COCO Salón de Belleza · SalonBelleza_DB
-- 04 · TABLAS · MÓDULO SERVICIOS

USE SalonBelleza_DB;
GO

-- 1. CategoriaServicio
CREATE TABLE Servicios.CategoriaServicio (
    CategoriaID INT          IDENTITY PRIMARY KEY,
    Nombre      VARCHAR(100) NOT NULL UNIQUE
);

-- 2. SubcategoriaServicio
CREATE TABLE Servicios.SubcategoriaServicio (
    SubcategoriaID INT          IDENTITY PRIMARY KEY,
    CategoriaID    INT          NOT NULL,
    Nombre         VARCHAR(100) NOT NULL,
    FOREIGN KEY (CategoriaID) REFERENCES Servicios.CategoriaServicio(CategoriaID)
);

-- 3. SubcategoriaRol
--    Define qué roles laborales pueden realizar cada subcategoría
CREATE TABLE Servicios.SubcategoriaRol (
    SubcategoriaID INT NOT NULL,
    RolID          INT NOT NULL,
    PRIMARY KEY (SubcategoriaID, RolID),
    FOREIGN KEY (SubcategoriaID) REFERENCES Servicios.SubcategoriaServicio(SubcategoriaID),
    FOREIGN KEY (RolID)          REFERENCES RRHH.Rol(RolID)
);

-- 4. Servicio
CREATE TABLE Servicios.Servicio (
    ServicioID     INT          IDENTITY PRIMARY KEY,
    Nombre         VARCHAR(150) NOT NULL,
    DuracionMin    INT          NOT NULL CHECK (DuracionMin > 0),
    SubcategoriaID INT          NOT NULL,
    Descripcion    VARCHAR(255) NOT NULL,
    Activo         BIT          NOT NULL DEFAULT 1,
    FOREIGN KEY (SubcategoriaID) REFERENCES Servicios.SubcategoriaServicio(SubcategoriaID)
);
GO

ALTER TABLE Servicios.Servicio
    ADD CONSTRAINT UQ_Servicio_Nombre UNIQUE (Nombre);
GO

-- 5. ServicioPrecio
--    Historial de precios por servicio (FechaFin = NULL → precio vigente)
CREATE TABLE Servicios.ServicioPrecio (
    ServicioPrecioID INT           IDENTITY PRIMARY KEY,
    ServicioID       INT           NOT NULL,
    Precio           DECIMAL(10,2) NOT NULL CHECK (Precio > 0),
    FechaInicio      DATE          NOT NULL,
    FechaFin         DATE          NULL,
    FOREIGN KEY (ServicioID) REFERENCES Servicios.Servicio(ServicioID),
    CHECK (FechaFin IS NULL OR FechaFin > FechaInicio)
);