-- COCO Salón de Belleza · SalonBelleza_DB
-- 09 · TABLAS · MÓDULO FACTURACIÓN

USE SalonBelleza_DB;
GO

-- 1. Factura
--    Una factura por venta (relación 1:1)
--    Estado: 'emitida' | 'pagada' | 'anulada'
CREATE TABLE Facturacion.Factura (
    FacturaID     INT          IDENTITY PRIMARY KEY,
    VentaID       INT          NOT NULL UNIQUE,
    NumeroFactura VARCHAR(50)  NOT NULL UNIQUE,
    Fecha         DATETIME     NOT NULL DEFAULT GETDATE(),
    Estado        VARCHAR(20)  NOT NULL DEFAULT 'emitida'
                  CHECK (Estado IN ('emitida','pagada','anulada')),
    FOREIGN KEY (VentaID) REFERENCES Ventas.Venta(VentaID)
);