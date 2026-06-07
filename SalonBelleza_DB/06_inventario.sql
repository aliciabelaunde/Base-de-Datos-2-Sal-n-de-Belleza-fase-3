-- COCO Salón de Belleza · SalonBelleza_DB
-- 06 · TABLAS · MÓDULO INVENTARIO

USE SalonBelleza_DB;
GO

-- 1. Proveedor
CREATE TABLE Inventario.Proveedor (
    ProveedorID INT          IDENTITY PRIMARY KEY,
    Nombre      VARCHAR(100) NOT NULL,
    Telefono    VARCHAR(20),
    Email       VARCHAR(100),
    Activo      BIT          NOT NULL DEFAULT 1
);

-- 2. Producto
CREATE TABLE Inventario.Producto (
    ProductoID   INT          IDENTITY PRIMARY KEY,
    Nombre       VARCHAR(100) NOT NULL,
    StockActual  INT          NOT NULL DEFAULT 0 CHECK (StockActual >= 0),
    StockMinimo  INT          NOT NULL DEFAULT 0,
    UnidadMedida VARCHAR(20)  NOT NULL,
    Activo       BIT          NOT NULL DEFAULT 1
);

-- 3. ProductoProveedor
CREATE TABLE Inventario.ProductoProveedor (
    ProductoID  INT NOT NULL,
    ProveedorID INT NOT NULL,
    PRIMARY KEY (ProductoID, ProveedorID),
    FOREIGN KEY (ProductoID)  REFERENCES Inventario.Producto(ProductoID),
    FOREIGN KEY (ProveedorID) REFERENCES Inventario.Proveedor(ProveedorID)
);

-- 4. ProductoPrecio
--    Historial de precios por producto (FechaFin = NULL → precio vigente)
CREATE TABLE Inventario.ProductoPrecio (
    ProductoPrecioID INT           IDENTITY PRIMARY KEY,
    ProductoID       INT           NOT NULL,
    Precio           DECIMAL(10,2) NOT NULL CHECK (Precio > 0),
    FechaInicio      DATE          NOT NULL,
    FechaFin         DATE          NULL,
    FOREIGN KEY (ProductoID) REFERENCES Inventario.Producto(ProductoID),
    CHECK (FechaFin IS NULL OR FechaFin > FechaInicio)
);

-- 5. MovimientoInventario
--    EsEntrada: 1 = sube stock · 0 = baja stock
CREATE TABLE Inventario.MovimientoInventario (
    MovimientoID INT      IDENTITY PRIMARY KEY,
    ProductoID   INT      NOT NULL,
    EsEntrada    BIT      NOT NULL,
    Cantidad     INT      NOT NULL CHECK (Cantidad > 0),
    Fecha        DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (ProductoID) REFERENCES Inventario.Producto(ProductoID)
);