-- COCO Salón de Belleza · SalonBelleza_DB
-- 18 · DATOS INICIALES

USE SalonBelleza_DB;
GO

-- 1. Roles de seguridad
--    RolID 1=Dueño/a  2=Administrador  3=Cliente
--    RolID 4=Atención y soporte  5=Personal técnico
INSERT INTO Seguridad.Rol (Nombre) VALUES
('Dueño/a'), ('Administrador'), ('Cliente'),
('Atención y soporte'), ('Personal técnico');
GO

-- 2. Roles laborales
--    RolID 1=Administrador  2=Estilista  3=Colorista
--    RolID 4=Manicurista/Pedicurista  5=Maquillador/a  6=Recepcionista
INSERT INTO RRHH.Rol (NombreRol) VALUES
('Administrador'), ('Estilista'), ('Colorista'),
('Manicurista / Pedicurista'), ('Maquillador/a'), ('Recepcionista');
GO

-- 3. Métodos de pago
INSERT INTO Ventas.MetodoPago (Nombre) VALUES
('Efectivo'), ('Tarjeta de débito'), ('Tarjeta de crédito'), ('QR / Transferencia');
GO

-- 4. Estados de cita
--    IDs reales resultantes: 8=Programada  9=Confirmada  10=En curso
--    11=Completada  12=Cancelada  13=No asistió
INSERT INTO Agenda.EstadoCita (Nombre) VALUES
('Programada'), ('Confirmada'), ('En curso'),
('Completada'), ('Cancelada'), ('No asistió');
GO

-- 5. Tipos de notificación
INSERT INTO Notificaciones.TipoNotificacion (Nombre) VALUES
('recordatorio_cita'),        -- 1
('bienvenida'),               -- 2
('stock_minimo'),             -- 3
('actualizacion_sueldo'),     -- 4
('aprobacion_excepcion'),     -- 5
('nuevo_cliente'),            -- 6
('cancelacion_cita');         -- 7
GO

-- IDs fijos para solicitudes especiales (requieren IDENTITY_INSERT)
SET IDENTITY_INSERT Notificaciones.TipoNotificacion ON;
IF NOT EXISTS (SELECT 1 FROM Notificaciones.TipoNotificacion WHERE TipoNotificacionID = 8)
    INSERT INTO Notificaciones.TipoNotificacion (TipoNotificacionID, Nombre) VALUES (8, 'solicitud_aprobada');
IF NOT EXISTS (SELECT 1 FROM Notificaciones.TipoNotificacion WHERE TipoNotificacionID = 9)
    INSERT INTO Notificaciones.TipoNotificacion (TipoNotificacionID, Nombre) VALUES (9, 'solicitud_rechazada');
SET IDENTITY_INSERT Notificaciones.TipoNotificacion OFF;
GO

-- 6. Categorías de servicio
INSERT INTO Servicios.CategoriaServicio (Nombre) VALUES
('Cabello'), ('Coloración'), ('Tratamientos Capilares'),
('Uñas'), ('Maquillaje'), ('Paquetes');
GO

-- 7. Subcategorías de servicio
INSERT INTO Servicios.SubcategoriaServicio (CategoriaID, Nombre) VALUES
-- Cabello (CategoriaID = 1)
(1, 'Corte'), (1, 'Peinado'), (1, 'Lavado'), (1, 'Alisado'),
-- Coloración (CategoriaID = 2)
(2, 'Tinte Completo'), (2, 'Mechas'), (2, 'Balayage'), (2, 'Decoloración'), (2, 'Corrección de Color'),
-- Tratamientos Capilares (CategoriaID = 3)
(3, 'Hidratación'), (3, 'Reparación'), (3, 'Keratina'), (3, 'Botox Capilar'), (3, 'Detox Capilar'),
-- Uñas (CategoriaID = 4)
(4, 'Manicure'), (4, 'Pedicure'), (4, 'Uñas Acrílicas'), (4, 'Uñas en Gel'), (4, 'Nail Art'), (4, 'Retiro de Uñas'),
-- Maquillaje (CategoriaID = 5)
(5, 'Maquillaje Social'), (5, 'Maquillaje de Novia'), (5, 'Maquillaje Artístico'), (5, 'Prueba de Maquillaje'),
-- Paquetes (CategoriaID = 6)
(6, 'Graduación'), (6, 'Boda'), (6, 'Quinceañera');
GO

-- 8. Roles por subcategoría
--    Estilista=2  Colorista=3  Manicurista=4  Maquillador=5
INSERT INTO Servicios.SubcategoriaRol (SubcategoriaID, RolID) VALUES
-- Cabello → Estilista (2)
(1,2),(2,2),(3,2),(4,2),
-- Coloración → Colorista (3)
(5,3),(6,3),(7,3),(8,3),(9,3),
-- Tratamientos → Estilista (2)
(10,2),(11,2),(12,2),(13,2),(14,2),
-- Uñas → Manicurista (4)
(15,4),(16,4),(17,4),(18,4),(19,4),(20,4),
-- Maquillaje → Maquillador (5)
(21,5),(22,5),(23,5),(24,5),
-- Paquetes → Estilista + Maquillador
(25,2),(25,5),(26,2),(26,5),(27,2),(27,5);
GO

-- 9. Servicios
INSERT INTO Servicios.Servicio (Nombre, DuracionMin, SubcategoriaID, Descripcion, Activo) VALUES
-- Corte (subcategoriaID 1)
('Corte Sólido',             30,  1, 'Corte recto, en V o en U', 1),
('Corte Encapado',           45,  1, 'Degradé, mariposa, degrafilado, curtain bangs', 1),
('Corte Bob / Pixie',        40,  1, 'Pixie cut, long bob, bob clásico', 1),
-- Peinado (2)
('Planchado',                30,  2, 'Peinado liso con plancha profesional', 1),
('Ondas al Agua / Bucleado', 45,  2, 'Ondas o bucles con tenaza o difusor', 1),
('Cepillado',                30,  2, 'Peinado liso con cepillo redondo y secadora', 1),
('Semirecogido Lacio u Ondas',60, 2, 'Medias colas, colas bajas y altas', 1),
('Ondas Calaminadas',        70,  2, 'Ondas marcadas estilo retro con ondulador', 1),
('Ondas Hollywood',          80,  2, 'Peinado glamour estilo Hollywood clásico', 1),
('Moño Simple (Lamido)',     60,  2, 'Moño clásico con acabado liso y pulido', 1),
('Moño Elaborado (Descontrolado)', 90, 2, 'Moño con texturas y estilo natural-artístico', 1),
-- Lavado (3)
('Lavado Neutro',            30,  3, 'Lavado y acondicionado con productos brasileros', 1),
('Lavado LOréal',            30,  3, 'Lavado y acondicionado con línea LOréal', 1),
-- Alisado (4)
('Alisado Temporal',         60,  4, 'Alisado con calor, dura hasta el próximo lavado', 1),
('Alisado Permanente',      120,  4, 'Alisado químico de larga duración', 1),
('Alisado con Proteínas',    90,  4, 'Alisado nutritivo con complejo de proteínas', 1),
-- Tinte (5)
('Tinte Completo Cabello Corto',  90, 5, 'Coloración total en cabello corto', 1),
('Tinte Completo Cabello Medio', 120, 5, 'Coloración total en cabello a los hombros', 1),
('Tinte Completo Cabello Largo', 150, 5, 'Coloración total en cabello largo', 1),
-- Mechas (6)
('Mechas Clásicas',         120,  6, 'Mechones uniformes con papel de aluminio', 1),
('Mechas Babylights',       150,  6, 'Mechones muy finos para efecto natural', 1),
('Mechas Inversas',         120,  6, 'Mechones más oscuros que el color base', 1),
-- Balayage (7)
('Balayage Clásico',        150,  7, 'Técnica de pintura a mano degradada', 1),
('Balayage con Tono',       180,  7, 'Balayage con aplicación de tono personalizado', 1),
('Balayage + Matizado',     210,  7, 'Balayage con baño de color o matizador', 1),
-- Decoloración (8)
('Decoloración Parcial',    120,  8, 'Decoloración en zonas específicas', 1),
('Decoloración Total',      180,  8, 'Decoloración completa del cabello', 1),
('Decoloración + Tonificación', 210, 8, 'Decoloración y aplicación de tono final', 1),
-- Corrección de Color (9)
('Corrección de Color Parcial', 120, 9, 'Ajuste de color en zonas específicas', 1),
('Corrección de Color Total',   180, 9, 'Reformulación completa del color del cabello', 1),
-- Hidratación (10)
('Hidratación Express',      45, 10, 'Mascarilla hidratante de acción rápida', 1),
('Hidratación Profunda',     60, 10, 'Tratamiento hidratante con vapor o calor', 1),
-- Reparación (11)
('Reparación con Proteínas', 60, 11, 'Tratamiento reconstructor para cabello dañado', 1),
('Reparación Ampolla',       45, 11, 'Aplicación de ampolla reparadora concentrada', 1),
-- Keratina (12)
('Keratina Brasilera',      150, 12, 'Alisado y nutrición con keratina brasilera', 1),
('Keratina Express',         90, 12, 'Tratamiento rápido de keratina sin formol', 1),
-- Botox Capilar (13)
('Botox Capilar',           120, 13, 'Relleno de fibra capilar, brillo y suavidad extrema', 1),
-- Detox Capilar (14)
('Detox Capilar',            60, 14, 'Limpieza profunda del cuero cabelludo y fibra', 1),
-- Manicure (15)
('Manicure Tradicional',     45, 15, 'Limpieza, forma y esmalte tradicional', 1),
('Manicure Semipermanente',  60, 15, 'Esmalte gel de larga duración con lámpara UV', 1),
-- Pedicure (16)
('Pedicure Tradicional',     60, 16, 'Limpieza, exfoliación, forma y esmalte', 1),
('Pedicure Semipermanente',  75, 16, 'Pedicure con esmalte gel de larga duración', 1),
('Pedicure Spa',             90, 16, 'Pedicure completo con hidratación y masaje', 1),
-- Uñas Acrílicas (17)
('Uñas Acrílicas Naturales',    90, 17, 'Esculpido en acrílico con acabado natural', 1),
('Uñas Acrílicas con Diseño',  120, 17, 'Esculpido acrílico con decoración personalizada', 1),
('Relleno Acrílico',            60, 17, 'Mantenimiento de crecimiento en uñas acrílicas', 1),
-- Uñas en Gel (18)
('Uñas en Gel Naturales',   90, 18, 'Esculpido en gel con acabado natural', 1),
('Uñas en Gel con Diseño', 120, 18, 'Esculpido en gel con decoración personalizada', 1),
('Relleno en Gel',          60, 18, 'Mantenimiento de crecimiento en uñas de gel', 1),
-- Nail Art (19)
('Nail Art Simple',         30, 19, 'Diseño sencillo: líneas, puntos, flores básicas', 1),
('Nail Art Elaborado',      60, 19, 'Diseño complejo: 3D, degradado, encapsulado', 1),
-- Retiro de Uñas (20)
('Retiro de Uñas Acrílicas', 30, 20, 'Retiro seguro de uñas acrílicas', 1),
('Retiro de Uñas en Gel',    30, 20, 'Retiro seguro de uñas en gel', 1),
('Retiro de Semipermanente', 20, 20, 'Retiro de esmalte semipermanente', 1),
-- Maquillaje Social (21)
('Maquillaje Social Día',    60, 21, 'Maquillaje natural para eventos diurnos', 1),
('Maquillaje Social Noche',  75, 21, 'Maquillaje glamour para eventos nocturnos', 1),
-- Maquillaje de Novia (22)
('Maquillaje de Novia Clásico',  90, 22, 'Look elegante y atemporal para la novia', 1),
('Maquillaje de Novia Glam',    100, 22, 'Look sofisticado y de alto impacto', 1),
-- Maquillaje Artístico (23)
('Maquillaje Artístico Fantasía', 90, 23, 'Maquillaje creativo para shows o fotografía', 1),
('Maquillaje Caracterización',  120, 23, 'Transformación en personaje o caracterización', 1),
-- Prueba de Maquillaje (24)
('Prueba de Maquillaje Novia',  60, 24, 'Ensayo previo del look nupcial', 1),
('Prueba de Maquillaje Evento', 45, 24, 'Ensayo de maquillaje para evento especial', 1),
-- Paquetes (25/26/27)
('Paquete Graduación Básico',   120, 25, 'Peinado + maquillaje social para graduación', 1),
('Paquete Graduación Completo', 180, 25, 'Peinado + maquillaje + manicure para graduación', 1),
('Paquete Novia Completo',      240, 26, 'Peinado + maquillaje + uñas para la novia', 1),
('Paquete Damas de Honor',      180, 26, 'Peinado + maquillaje para damas de honor', 1),
('Paquete Quinceañera Básico',  150, 27, 'Peinado + maquillaje para quinceañera', 1),
('Paquete Quinceañera Premium', 210, 27, 'Peinado + maquillaje + uñas + pestañas', 1);
GO

-- 10. Precios de servicios
INSERT INTO Servicios.ServicioPrecio (ServicioID, Precio, FechaInicio, FechaFin) VALUES
(1,100.00,GETDATE(),NULL),(2,120.00,GETDATE(),NULL),(3,130.00,GETDATE(),NULL),
(4,100.00,GETDATE(),NULL),(5,100.00,GETDATE(),NULL),(6,100.00,GETDATE(),NULL),
(7,150.00,GETDATE(),NULL),(8,150.00,GETDATE(),NULL),(9,150.00,GETDATE(),NULL),
(10,150.00,GETDATE(),NULL),(11,180.00,GETDATE(),NULL),
(12,60.00,GETDATE(),NULL),(13,80.00,GETDATE(),NULL),
(14,120.00,GETDATE(),NULL),(15,350.00,GETDATE(),NULL),(16,200.00,GETDATE(),NULL),
(17,180.00,GETDATE(),NULL),(18,220.00,GETDATE(),NULL),(19,280.00,GETDATE(),NULL),
(20,200.00,GETDATE(),NULL),(21,250.00,GETDATE(),NULL),(22,200.00,GETDATE(),NULL),
(23,300.00,GETDATE(),NULL),(24,350.00,GETDATE(),NULL),(25,400.00,GETDATE(),NULL),
(26,200.00,GETDATE(),NULL),(27,320.00,GETDATE(),NULL),(28,380.00,GETDATE(),NULL),
(29,250.00,GETDATE(),NULL),(30,400.00,GETDATE(),NULL),
(31,80.00,GETDATE(),NULL),(32,120.00,GETDATE(),NULL),
(33,130.00,GETDATE(),NULL),(34,90.00,GETDATE(),NULL),
(35,400.00,GETDATE(),NULL),(36,250.00,GETDATE(),NULL),(37,380.00,GETDATE(),NULL),(38,150.00,GETDATE(),NULL),
(39,60.00,GETDATE(),NULL),(40,90.00,GETDATE(),NULL),
(41,80.00,GETDATE(),NULL),(42,110.00,GETDATE(),NULL),(43,140.00,GETDATE(),NULL),
(44,180.00,GETDATE(),NULL),(45,220.00,GETDATE(),NULL),(46,90.00,GETDATE(),NULL),
(47,190.00,GETDATE(),NULL),(48,230.00,GETDATE(),NULL),(49,95.00,GETDATE(),NULL),
(50,50.00,GETDATE(),NULL),(51,100.00,GETDATE(),NULL),
(52,50.00,GETDATE(),NULL),(53,50.00,GETDATE(),NULL),(54,30.00,GETDATE(),NULL),
(55,120.00,GETDATE(),NULL),(56,160.00,GETDATE(),NULL),
(57,300.00,GETDATE(),NULL),(58,380.00,GETDATE(),NULL),
(59,200.00,GETDATE(),NULL),(60,280.00,GETDATE(),NULL),
(61,150.00,GETDATE(),NULL),(62,100.00,GETDATE(),NULL),
(63,300.00,GETDATE(),NULL),(64,420.00,GETDATE(),NULL),
(65,700.00,GETDATE(),NULL),(66,450.00,GETDATE(),NULL),
(67,380.00,GETDATE(),NULL),(68,520.00,GETDATE(),NULL);
GO

-- 11. Dueñas
-- Contraseña de todos los usuarios de prueba: Coco2026!
DECLARE @hash VARCHAR(255) = '$2b$10$OXXzr2pUqCgmOvSsy127wOcP0OxM3BxD.UV0x1cL1YSCf0hXhZL62';
DECLARE @ID INT, @UID INT;

INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email)
VALUES ('Alicia','Belaunde','+591 79886101','duena1@coco.com');
SET @ID = SCOPE_IDENTITY();
INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@ID,'duena1@coco.com',@hash);
SET @UID = SCOPE_IDENTITY();
INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UID,1);

INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email)
VALUES ('Paola','Quinteros','+591 77455834','duena2@coco.com');
SET @ID = SCOPE_IDENTITY();
INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@ID,'duena2@coco.com',@hash);
SET @UID = SCOPE_IDENTITY();
INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UID,1);
GO

-- 12. Administradores
DECLARE @hash VARCHAR(255) = '$2b$10$OXXzr2pUqCgmOvSsy127wOcP0OxM3BxD.UV0x1cL1YSCf0hXhZL62';
DECLARE @ID INT, @UID INT;

INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email)
VALUES ('Lucia','Lopez','+591 70000002','admin1@coco.com');
SET @ID = SCOPE_IDENTITY();
INSERT INTO RRHH.Empleado (EmpleadoID,FechaContratacion,Activo) VALUES (@ID,GETDATE(),1);
INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID) VALUES (@ID,1);
INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@ID,5000.00,GETDATE());
INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@ID,0.00,GETDATE());
INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@ID,'admin1@coco.com',@hash);
SET @UID = SCOPE_IDENTITY();
INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UID,2);

INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email)
VALUES ('Martina','Guzman','+591 78846452','admin2@coco.com');
SET @ID = SCOPE_IDENTITY();
INSERT INTO RRHH.Empleado (EmpleadoID,FechaContratacion,Activo) VALUES (@ID,GETDATE(),1);
INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID) VALUES (@ID,1);
INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@ID,5000.00,GETDATE());
INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@ID,0.00,GETDATE());
INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@ID,'admin2@coco.com',@hash);
SET @UID = SCOPE_IDENTITY();
INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UID,2);
GO

-- 13. Personal técnico
DECLARE @hash VARCHAR(255) = '$2b$10$OXXzr2pUqCgmOvSsy127wOcP0OxM3BxD.UV0x1cL1YSCf0hXhZL62';
DECLARE @ID INT, @UID INT;

-- Estilista
INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email)
VALUES ('María','González','+591 70000010','maria@coco.com');
SET @ID = SCOPE_IDENTITY();
INSERT INTO RRHH.Empleado (EmpleadoID,FechaContratacion,Activo) VALUES (@ID,GETDATE(),1);
INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID) VALUES (@ID,2);  -- Estilista
INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@ID,3200.00,GETDATE());
INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@ID,15.00,GETDATE());
INSERT INTO RRHH.HorarioEmpleado (EmpleadoID,DiaSemana,HoraEntrada,HoraSalida,Activo) VALUES
    (@ID,1,'09:00','19:00',1),(@ID,2,'09:00','19:00',1),(@ID,3,'09:00','19:00',1),
    (@ID,4,'09:00','19:00',1),(@ID,5,'09:00','19:00',1),(@ID,6,'09:00','14:00',1);
INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@ID,'maria@coco.com',@hash);
SET @UID = SCOPE_IDENTITY();
INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UID,5);  -- Personal técnico

-- Manicurista
INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email)
VALUES ('Karen','Reyes','+591 70000011','karen@coco.com');
SET @ID = SCOPE_IDENTITY();
INSERT INTO RRHH.Empleado (EmpleadoID,FechaContratacion,Activo) VALUES (@ID,GETDATE(),1);
INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID) VALUES (@ID,4);  -- Manicurista
INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@ID,2800.00,GETDATE());
INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@ID,15.00,GETDATE());
INSERT INTO RRHH.HorarioEmpleado (EmpleadoID,DiaSemana,HoraEntrada,HoraSalida,Activo) VALUES
    (@ID,1,'09:00','19:00',1),(@ID,2,'09:00','19:00',1),(@ID,3,'09:00','19:00',1),
    (@ID,4,'09:00','19:00',1),(@ID,5,'09:00','19:00',1),(@ID,6,'09:00','14:00',1);
INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@ID,'karen@coco.com',@hash);
SET @UID = SCOPE_IDENTITY();
INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UID,5);

-- Colorista (tiene doble rol: Personal técnico + Atención por ser tutora)
INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email)
VALUES ('Lucía','Flores','+591 70000012','lucia@coco.com');
SET @ID = SCOPE_IDENTITY();
INSERT INTO RRHH.Empleado (EmpleadoID,FechaContratacion,Activo) VALUES (@ID,GETDATE(),1);
INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID) VALUES (@ID,3);  -- Colorista
INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@ID,3000.00,GETDATE());
INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@ID,15.00,GETDATE());
INSERT INTO RRHH.HorarioEmpleado (EmpleadoID,DiaSemana,HoraEntrada,HoraSalida,Activo) VALUES
    (@ID,1,'09:00','19:00',1),(@ID,2,'09:00','19:00',1),(@ID,3,'09:00','19:00',1),
    (@ID,4,'09:00','19:00',1),(@ID,5,'09:00','19:00',1),(@ID,6,'09:00','14:00',1);
INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@ID,'lucia@coco.com',@hash);
SET @UID = SCOPE_IDENTITY();
INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UID,4),(@UID,5);  -- Atención + Personal técnico
GO

-- 14. Recepcionista
DECLARE @hash VARCHAR(255) = '$2b$10$OXXzr2pUqCgmOvSsy127wOcP0OxM3BxD.UV0x1cL1YSCf0hXhZL62';
DECLARE @ID INT, @UID INT;

INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email)
VALUES ('María','Prado','+591 70000013','mprado@coco.com');
SET @ID = SCOPE_IDENTITY();
INSERT INTO RRHH.Empleado (EmpleadoID,FechaContratacion,Activo) VALUES (@ID,GETDATE(),1);
INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID) VALUES (@ID,6);  -- Recepcionista
INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@ID,2400.00,GETDATE());
INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@ID,0.00,GETDATE());
INSERT INTO RRHH.HorarioEmpleado (EmpleadoID,DiaSemana,HoraEntrada,HoraSalida,Activo) VALUES
    (@ID,1,'08:30','19:00',1),(@ID,2,'08:30','19:00',1),(@ID,3,'08:30','19:00',1),
    (@ID,4,'08:30','19:00',1),(@ID,5,'08:30','19:00',1),(@ID,6,'08:30','14:30',1);
INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@ID,'mprado@coco.com',@hash);
SET @UID = SCOPE_IDENTITY();
INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UID,4);  -- Atención y soporte
GO

-- 15. Promociones
INSERT INTO Marketing.Promocion (Nombre, Descripcion, FechaInicio, FechaFin, Descuento, Activo, TipoPromocion) VALUES
('Día de la Mujer',   'Descuento especial en todos los servicios para celebrar a la mujer', '2026-03-07','2026-03-08', 20.00, 1, 'general'),
('Día de la Madre',   'Descuento en maquillaje y peinados para consentir a mamá',           '2026-05-25','2026-05-31', 15.00, 1, 'general'),
('Mes de Graduación', 'Descuento en paquetes de graduación durante la temporada',           '2026-11-01','2026-12-01', 10.00, 1, 'general'),
('Cumpleaños',        '¡Descuento especial el mes de tu cumpleaños en cualquier servicio!', '2026-01-01','2026-12-31', 25.00, 1, 'cumpleanos');
GO

-- 16. Servicios en promociones
INSERT INTO Marketing.PromocionServicio (PromocionID, ServicioID) VALUES
-- Día de la Mujer (1)
(1,1),(1,2),(1,3),(1,4),(1,5),(1,6),(1,55),(1,56),
-- Día de la Madre (2)
(2,4),(2,5),(2,10),(2,11),(2,31),(2,32),(2,55),(2,56),
-- Mes de Graduación (3)
(3,63),(3,64),
-- Cumpleaños (4) — servicios populares
(4,1),(4,2),(4,3),(4,4),(4,5),(4,6),(4,7),(4,8),(4,9),(4,10),(4,11),
(4,12),(4,13),(4,31),(4,32),(4,37),(4,39),(4,40),(4,41),(4,42),(4,43),(4,55),(4,56);
GO

-- 17. Descripción de la promo cumpleaños
UPDATE Marketing.Promocion
SET Descripcion = '¡Descuento especial el día de tu cumpleaños en cualquier servicio!'
WHERE PromocionID = 4;
GO

-- 18. Proveedores e inventario
INSERT INTO Inventario.Proveedor (Nombre, Telefono, Email, Activo) VALUES
('L''Oréal Profesional',       '+591 70000001', 'contacto@loreal-profesional.com', 1),
('Wella Professionals',        '+591 70000002', 'ventas@wella.com',                1),
('Schwarzkopf Professional',   '+591 70000003', 'info@schwarzkopf.com',            1),
('OPI Products',               '+591 70000004', 'soporte@opi.com',                 1),
('Moroccanoil',                '+591 70000005', 'ventas@moroccanoil.com',           1);

INSERT INTO Inventario.Producto (Nombre, StockActual, StockMinimo, UnidadMedida, Activo) VALUES
('Shampoo Profesional Reparador', 20, 5,  'ml',     1),
('Acondicionador Hidratante',     15, 5,  'ml',     1),
('Tinte Negro Intenso',           30, 10, 'unidad', 1),
('Tinte Rubio Claro',             25, 10, 'unidad', 1),
('Oxidante 20 Vol',               40, 10, 'ml',     1),
('Esmalte Gel Rojo',              10, 3,  'unidad', 1),
('Esmalte Gel Nude',               8, 3,  'unidad', 1),
('Removedor de Gel',              12, 4,  'ml',     1),
('Aceite Capilar Argán',           6, 2,  'ml',     1),
('Spray Fijador',                 14, 5,  'ml',     1);

INSERT INTO Inventario.ProductoPrecio (ProductoID, Precio, FechaInicio, FechaFin) VALUES
(1,80.00,'2025-01-01',NULL),(2,75.00,'2025-01-01',NULL),(3,50.00,'2025-01-01',NULL),
(4,55.00,'2025-01-01',NULL),(5,40.00,'2025-01-01',NULL),(6,60.00,'2025-01-01',NULL),
(7,60.00,'2025-01-01',NULL),(8,35.00,'2025-01-01',NULL),(9,120.00,'2025-01-01',NULL),
(10,70.00,'2025-01-01',NULL);
GO