-- COCO Salón de Belleza · SalonBelleza_DB
-- 13 · ÍNDICES

USE SalonBelleza_DB;
GO

-- MÓDULO ADMINISTRADOR

-- 1. Productos por categoría y stock
CREATE INDEX IX_Producto_Activo
ON Inventario.Producto(Activo);

-- 2. Precio vigente de producto
CREATE INDEX IX_ProductoPrecio_Vigente
ON Inventario.ProductoPrecio(ProductoID, FechaFin);

-- 3. Movimientos de inventario por producto
CREATE INDEX IX_MovimientoInventario_Producto
ON Inventario.MovimientoInventario(ProductoID, Fecha);

-- 4. Ventas por período para reportes
CREATE INDEX IX_Venta_FechaEstado
ON Ventas.Venta(Fecha, Estado);

-- 5. Promociones vigentes
CREATE INDEX IX_Promocion_Activa
ON Marketing.Promocion(FechaInicio, FechaFin);

-- 6. Nómina por período
CREATE INDEX IX_PagoNomina_Periodo
ON RRHH.PagoNomina(Periodo);
GO