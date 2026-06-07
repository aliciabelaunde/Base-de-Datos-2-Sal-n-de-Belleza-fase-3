-- COCO Salón de Belleza · SalonBelleza_DB
-- 10 · TABLAS · MÓDULO PAGOS

USE SalonBelleza_DB;
GO

-- 1. MetodoPago
CREATE TABLE Ventas.MetodoPago (
    MetodoPagoID INT         IDENTITY PRIMARY KEY,
    Nombre       VARCHAR(50) NOT NULL UNIQUE
);

-- 2. Pago
--    Una venta puede tener múltiples pagos (pago dividido)
CREATE TABLE Ventas.Pago (
    PagoID       INT           IDENTITY PRIMARY KEY,
    VentaID      INT           NOT NULL,
    MetodoPagoID INT           NOT NULL,
    Monto        DECIMAL(10,2) NOT NULL CHECK (Monto > 0),
    Fecha        DATETIME      NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (VentaID)      REFERENCES Ventas.Venta(VentaID),
    FOREIGN KEY (MetodoPagoID) REFERENCES Ventas.MetodoPago(MetodoPagoID)
);