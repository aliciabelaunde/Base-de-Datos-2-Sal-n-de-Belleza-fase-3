-- COCO Salón de Belleza · SalonBelleza_DB
-- 07 · TABLAS · MÓDULO VENTAS

USE SalonBelleza_DB;
GO

-- 1. Cliente
--    Extiende Personas.Persona como cliente del salón
CREATE TABLE Ventas.Cliente (
    ClienteID INT PRIMARY KEY,
    FOREIGN KEY (ClienteID) REFERENCES Personas.Persona(PersonaID)
);

-- 2. ClienteDetalle
--    Información médica y técnica del cliente
CREATE TABLE Ventas.ClienteDetalle (
    ClienteID          INT PRIMARY KEY,
    Alergias           VARCHAR(MAX),
    Contraindicaciones VARCHAR(MAX),
    NotasTecnicas      VARCHAR(MAX),
    FOREIGN KEY (ClienteID) REFERENCES Ventas.Cliente(ClienteID)
);

-- 3. Venta
--    EmpleadoID nullable para ventas de solo productos
--    Columnas de descuento y promoción agregadas posteriormente
CREATE TABLE Ventas.Venta (
    VentaID         INT           IDENTITY PRIMARY KEY,
    ClienteID       INT           NOT NULL,
    EmpleadoID      INT           NULL,
    Fecha           DATETIME      NOT NULL DEFAULT GETDATE(),
    Estado          VARCHAR(20)   NOT NULL DEFAULT 'pendiente'
                    CHECK (Estado IN ('pendiente','pagado','cancelado')),
    DescuentoPct    DECIMAL(5,2)  NULL DEFAULT 0,
    DescuentoMonto  DECIMAL(10,2) NULL DEFAULT 0,
    PromocionID     INT           NULL,
    FOREIGN KEY (ClienteID)  REFERENCES Ventas.Cliente(ClienteID),
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID)
);

-- 4. VentaDetalleProducto
CREATE TABLE Ventas.VentaDetalleProducto (
    VentaDetalleProductoID INT           IDENTITY PRIMARY KEY,
    VentaID                INT           NOT NULL,
    ProductoID             INT           NOT NULL,
    Cantidad               INT           NOT NULL CHECK (Cantidad > 0),
    PrecioUnitario         DECIMAL(10,2) NOT NULL CHECK (PrecioUnitario > 0),
    FOREIGN KEY (VentaID)    REFERENCES Ventas.Venta(VentaID),
    FOREIGN KEY (ProductoID) REFERENCES Inventario.Producto(ProductoID)
);

-- 5. VentaDetalleServicio
--    EmpleadoID por servicio para cálculo correcto de comisiones
CREATE TABLE Ventas.VentaDetalleServicio (
    VentaDetalleServicioID INT           IDENTITY PRIMARY KEY,
    VentaID                INT           NOT NULL,
    ServicioID             INT           NOT NULL,
    Cantidad               INT           NOT NULL CHECK (Cantidad > 0),
    PrecioUnitario         DECIMAL(10,2) NOT NULL CHECK (PrecioUnitario > 0),
    EmpleadoID             INT           NULL,
    FOREIGN KEY (VentaID)    REFERENCES Ventas.Venta(VentaID),
    FOREIGN KEY (ServicioID) REFERENCES Servicios.Servicio(ServicioID)
);