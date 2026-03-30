-- ==============================================================
--  BASE DE DATOS FACTURACIÓN - MySQL/MariaDB 10.4+
--  Conversión completa desde PostgreSQL
--  Incluye: Tablas, Triggers, Stored Procedures, Datos y RBAC
-- ==============================================================

-- ================================================================
-- CREAR Y SELECCIONAR BASE DE DATOS
-- ================================================================
CREATE DATABASE IF NOT EXISTS bdfacturas_mariadb_local
    DEFAULT CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE bdfacturas_mariadb_local;

-- Forzar UTF-8 en la conexión para que los INSERT guarden bien las tildes
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- ================================================================
-- ELIMINAR OBJETOS EXISTENTES (para poder re-ejecutar el script)
-- ================================================================
DROP PROCEDURE IF EXISTS crear_factura_con_detalle;
DROP PROCEDURE IF EXISTS actualizar_factura_con_detalle;
DROP PROCEDURE IF EXISTS eliminar_factura_con_detalle;
DROP PROCEDURE IF EXISTS consultar_factura_con_detalle;
DROP PROCEDURE IF EXISTS crear_usuario_con_roles;
DROP PROCEDURE IF EXISTS actualizar_usuario_con_roles;
DROP PROCEDURE IF EXISTS eliminar_usuario_con_roles;
DROP PROCEDURE IF EXISTS actualizar_roles_usuario;
DROP PROCEDURE IF EXISTS consultar_usuario_con_roles;
DROP PROCEDURE IF EXISTS listar_usuarios_con_roles;
DROP PROCEDURE IF EXISTS verificar_acceso_ruta;
DROP PROCEDURE IF EXISTS listar_rutarol;
DROP PROCEDURE IF EXISTS crear_rutarol;
DROP PROCEDURE IF EXISTS eliminar_rutarol;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS productosporfactura;
DROP TABLE IF EXISTS factura;
DROP TABLE IF EXISTS producto;
DROP TABLE IF EXISTS rutarol;
DROP TABLE IF EXISTS rol_usuario;
DROP TABLE IF EXISTS vendedor;
DROP TABLE IF EXISTS cliente;
DROP TABLE IF EXISTS ruta;
DROP TABLE IF EXISTS rol;
DROP TABLE IF EXISTS usuario;
DROP TABLE IF EXISTS empresa;
DROP TABLE IF EXISTS persona;
SET FOREIGN_KEY_CHECKS = 1;

-- ================================================================
-- TABLAS BASE
-- ================================================================
CREATE TABLE persona (
    codigo VARCHAR(20) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    telefono VARCHAR(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE empresa (
    codigo VARCHAR(10) PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE usuario (
    email VARCHAR(100) PRIMARY KEY,
    contrasena VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE rol (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ruta (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ruta VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE cliente (
    id INT AUTO_INCREMENT PRIMARY KEY,
    credito DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (credito >= 0),
    fkcodpersona VARCHAR(20) NOT NULL UNIQUE,
    fkcodempresa VARCHAR(10),
    FOREIGN KEY (fkcodpersona) REFERENCES persona (codigo),
    FOREIGN KEY (fkcodempresa) REFERENCES empresa (codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE vendedor (
    id INT AUTO_INCREMENT PRIMARY KEY,
    carnet INT NOT NULL,
    direccion VARCHAR(100) NOT NULL,
    fkcodpersona VARCHAR(20) NOT NULL UNIQUE,
    FOREIGN KEY (fkcodpersona) REFERENCES persona (codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE rol_usuario (
    fkemail VARCHAR(100) NOT NULL,
    fkidrol INT NOT NULL,
    PRIMARY KEY (fkemail, fkidrol),
    FOREIGN KEY (fkemail) REFERENCES usuario (email) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (fkidrol) REFERENCES rol (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE rutarol (
    fkidruta INT NOT NULL,
    fkidrol INT NOT NULL,
    PRIMARY KEY (fkidruta, fkidrol),
    FOREIGN KEY (fkidruta) REFERENCES ruta (id) ON DELETE CASCADE,
    FOREIGN KEY (fkidrol) REFERENCES rol (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE producto (
    codigo VARCHAR(30) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    stock INT NOT NULL CHECK (stock >= 0),
    valorunitario DECIMAL(14,2) NOT NULL CHECK (valorunitario >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE factura (
    numero INT AUTO_INCREMENT PRIMARY KEY,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    fkidcliente INT NOT NULL,
    fkidvendedor INT NOT NULL,
    FOREIGN KEY (fkidcliente) REFERENCES cliente (id),
    FOREIGN KEY (fkidvendedor) REFERENCES vendedor (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE productosporfactura (
    fknumfactura INT NOT NULL,
    fkcodproducto VARCHAR(30) NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    subtotal DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    PRIMARY KEY (fknumfactura, fkcodproducto),
    FOREIGN KEY (fknumfactura) REFERENCES factura (numero) ON DELETE CASCADE,
    FOREIGN KEY (fkcodproducto) REFERENCES producto (codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ================================================================
-- TRIGGERS: Actualizar totales y stock automáticamente
-- ================================================================
DELIMITER $$

-- Trigger BEFORE INSERT
CREATE TRIGGER trigger_productosporfactura_before_insert
BEFORE INSERT ON productosporfactura
FOR EACH ROW
BEGIN
    DECLARE v_precio DECIMAL(14,2);

    -- Obtener el precio unitario del producto
    SELECT valorunitario INTO v_precio FROM producto WHERE codigo = NEW.fkcodproducto;

    -- Calcular el subtotal
    SET NEW.subtotal = NEW.cantidad * v_precio;

    -- Actualizar el stock del producto (restar la cantidad vendida)
    UPDATE producto SET stock = stock - NEW.cantidad WHERE codigo = NEW.fkcodproducto;
END$$

-- Trigger AFTER INSERT
CREATE TRIGGER trigger_productosporfactura_after_insert
AFTER INSERT ON productosporfactura
FOR EACH ROW
BEGIN
    -- Actualizar el total de la factura
    UPDATE factura
    SET total = (SELECT COALESCE(SUM(subtotal), 0) FROM productosporfactura WHERE fknumfactura = NEW.fknumfactura)
    WHERE numero = NEW.fknumfactura;
END$$

-- Trigger BEFORE UPDATE
CREATE TRIGGER trigger_productosporfactura_before_update
BEFORE UPDATE ON productosporfactura
FOR EACH ROW
BEGIN
    DECLARE v_precio DECIMAL(14,2);

    -- Obtener el precio unitario del producto
    SELECT valorunitario INTO v_precio FROM producto WHERE codigo = NEW.fkcodproducto;

    -- Calcular el nuevo subtotal
    SET NEW.subtotal = NEW.cantidad * v_precio;

    -- Ajustar el stock: devolver la cantidad anterior y restar la nueva
    UPDATE producto
    SET stock = stock + OLD.cantidad - NEW.cantidad
    WHERE codigo = NEW.fkcodproducto;
END$$

-- Trigger AFTER UPDATE
CREATE TRIGGER trigger_productosporfactura_after_update
AFTER UPDATE ON productosporfactura
FOR EACH ROW
BEGIN
    -- Actualizar el total de la factura
    UPDATE factura
    SET total = (SELECT COALESCE(SUM(subtotal), 0) FROM productosporfactura WHERE fknumfactura = NEW.fknumfactura)
    WHERE numero = NEW.fknumfactura;
END$$

-- Trigger BEFORE DELETE
CREATE TRIGGER trigger_productosporfactura_before_delete
BEFORE DELETE ON productosporfactura
FOR EACH ROW
BEGIN
    -- Devolver el stock al producto
    UPDATE producto
    SET stock = stock + OLD.cantidad
    WHERE codigo = OLD.fkcodproducto;
END$$

-- Trigger AFTER DELETE
CREATE TRIGGER trigger_productosporfactura_after_delete
AFTER DELETE ON productosporfactura
FOR EACH ROW
BEGIN
    -- Actualizar el total de la factura
    UPDATE factura
    SET total = (SELECT COALESCE(SUM(subtotal), 0) FROM productosporfactura WHERE fknumfactura = OLD.fknumfactura)
    WHERE numero = OLD.fknumfactura;
END$$

DELIMITER ;

-- ================================================================
-- STORED PROCEDURES: Facturas (maestro-detalle)
-- ================================================================
DELIMITER $$

CREATE PROCEDURE crear_factura_con_detalle(
    IN p_fkidcliente INT,
    IN p_fkidvendedor INT,
    IN p_fecha TIMESTAMP,
    IN p_detalles JSON,
    IN p_minimo_detalle INT
)
BEGIN
    DECLARE v_numfactura INT;
    DECLARE v_index INT DEFAULT 0;
    DECLARE v_count INT;
    DECLARE v_codproducto VARCHAR(30);
    DECLARE v_cantidad INT;
    DECLARE v_minimo INT;

    -- COALESCE(NULLIF(p_minimo_detalle, 0), 1): la API envia 0 cuando no se pasa el parametro
    SET v_minimo = COALESCE(NULLIF(p_minimo_detalle, 0), 1);

    -- Validar minimo de productos
    IF p_detalles IS NULL OR JSON_LENGTH(p_detalles) < v_minimo THEN
        SET @v_msg = CONCAT('La factura requiere minimo ', v_minimo, ' producto(s).');
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = @v_msg;
    END IF;

    -- Insertar la factura
    INSERT INTO factura (fkidcliente, fkidvendedor, fecha)
    VALUES (p_fkidcliente, p_fkidvendedor, p_fecha);

    -- Obtener el número de factura generado
    SET v_numfactura = LAST_INSERT_ID();

    -- Obtener el número de elementos en el JSON
    SET v_count = JSON_LENGTH(p_detalles);

    -- Iterar sobre cada elemento del JSON
    WHILE v_index < v_count DO
        SET v_codproducto = JSON_UNQUOTE(JSON_EXTRACT(p_detalles, CONCAT('$[', v_index, '].fkcodproducto')));
        SET v_cantidad = JSON_EXTRACT(p_detalles, CONCAT('$[', v_index, '].cantidad'));

        -- Insertar el detalle de la factura
        INSERT INTO productosporfactura (fknumfactura, fkcodproducto, cantidad)
        VALUES (v_numfactura, v_codproducto, v_cantidad);

        SET v_index = v_index + 1;
    END WHILE;
END$$

CREATE PROCEDURE actualizar_factura_con_detalle(
    IN p_numfactura INT,
    IN p_fkidcliente INT,
    IN p_fkidvendedor INT,
    IN p_fecha TIMESTAMP,
    IN p_detalles JSON,
    IN p_minimo_detalle INT
)
BEGIN
    DECLARE v_index INT DEFAULT 0;
    DECLARE v_count INT;
    DECLARE v_codproducto VARCHAR(30);
    DECLARE v_cantidad INT;
    DECLARE v_minimo INT;

    -- COALESCE(NULLIF(p_minimo_detalle, 0), 1): la API envia 0 cuando no se pasa el parametro
    SET v_minimo = COALESCE(NULLIF(p_minimo_detalle, 0), 1);

    -- Validar minimo de productos
    IF p_detalles IS NULL OR JSON_LENGTH(p_detalles) < v_minimo THEN
        SET @v_msg = CONCAT('La factura requiere minimo ', v_minimo, ' producto(s).');
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = @v_msg;
    END IF;

    -- Actualizar la cabecera de la factura
    UPDATE factura
    SET fkidcliente = p_fkidcliente,
        fkidvendedor = p_fkidvendedor,
        fecha = p_fecha
    WHERE numero = p_numfactura;

    -- Eliminar los detalles anteriores (esto restaura el stock automáticamente por el trigger)
    DELETE FROM productosporfactura WHERE fknumfactura = p_numfactura;

    -- Obtener el número de elementos en el JSON
    SET v_count = JSON_LENGTH(p_detalles);

    -- Insertar los nuevos detalles
    WHILE v_index < v_count DO
        SET v_codproducto = JSON_UNQUOTE(JSON_EXTRACT(p_detalles, CONCAT('$[', v_index, '].fkcodproducto')));
        SET v_cantidad = JSON_EXTRACT(p_detalles, CONCAT('$[', v_index, '].cantidad'));

        INSERT INTO productosporfactura (fknumfactura, fkcodproducto, cantidad)
        VALUES (p_numfactura, v_codproducto, v_cantidad);

        SET v_index = v_index + 1;
    END WHILE;
END$$

CREATE PROCEDURE eliminar_factura_con_detalle(
    IN p_numfactura INT
)
BEGIN
    -- Eliminar la factura (los detalles se eliminan automáticamente por ON DELETE CASCADE)
    -- El trigger restaura el stock automáticamente
    DELETE FROM factura WHERE numero = p_numfactura;
END$$

-- CORREGIDO para MariaDB 10.4: sin JSON_ARRAYAGG ni CAST AS JSON
-- Se construye el JSON completo con CONCAT + GROUP_CONCAT
CREATE PROCEDURE consultar_factura_con_detalle(
    IN p_numfactura INT,
    OUT p_resultado JSON
)
BEGIN
    DECLARE v_detalle_json TEXT;

    -- Construir el array JSON del detalle usando GROUP_CONCAT
    SELECT CONCAT('[', COALESCE(GROUP_CONCAT(
        JSON_OBJECT(
            'fkcodproducto', d.fkcodproducto,
            'cantidad', d.cantidad,
            'subtotal', d.subtotal,
            'valorunitario', p.valorunitario
        )
    ), ''), ']')
    INTO v_detalle_json
    FROM productosporfactura d
    INNER JOIN producto p ON p.codigo = d.fkcodproducto
    WHERE d.fknumfactura = p_numfactura;

    -- Construir el resultado completo con CONCAT para anidar el JSON sin CAST
    SELECT CONCAT(
        '{"numero":', f.numero,
        ',"fecha":"', DATE_FORMAT(f.fecha, '%Y-%m-%d %H:%i:%s'), '"',
        ',"total":', f.total,
        ',"cliente":"', c.fkcodpersona, '"',
        ',"vendedor":"', v.fkcodpersona, '"',
        ',"detalle":', COALESCE(v_detalle_json, '[]'),
        '}'
    ) INTO p_resultado
    FROM factura f
    JOIN cliente c ON c.id = f.fkidcliente
    JOIN vendedor v ON v.id = f.fkidvendedor
    WHERE f.numero = p_numfactura;
END$$

-- ================================================================
-- STORED PROCEDURES: Usuarios con Roles
-- NOTA: El cifrado lo hace la API C# con el parámetro camposEncriptar
-- ================================================================

-- CORREGIDO: Formato unificado, espera [{"fkidrol":1}, {"fkidrol":2}]
-- (consistente con actualizar_usuario_con_roles y con los CALL de datos iniciales)
CREATE PROCEDURE crear_usuario_con_roles(
    IN p_email VARCHAR(100),
    IN p_contrasena VARCHAR(100),
    IN p_roles_json JSON
)
BEGIN
    DECLARE v_index INT DEFAULT 0;
    DECLARE v_count INT;
    DECLARE v_idrol INT;

    -- Insertar el usuario
    INSERT INTO usuario (email, contrasena)
    VALUES (p_email, p_contrasena);

    -- Obtener el número de roles en el array JSON
    SET v_count = JSON_LENGTH(p_roles_json);

    -- Insertar los roles del usuario (formato: [{"fkidrol":1}, {"fkidrol":2}])
    WHILE v_index < v_count DO
        SET v_idrol = JSON_EXTRACT(p_roles_json, CONCAT('$[', v_index, '].fkidrol'));

        INSERT INTO rol_usuario (fkemail, fkidrol)
        VALUES (p_email, v_idrol);

        SET v_index = v_index + 1;
    END WHILE;
END$$

CREATE PROCEDURE actualizar_usuario_con_roles(
    IN p_email VARCHAR(100),
    IN p_contrasena VARCHAR(100),
    IN p_roles JSON
)
BEGIN
    DECLARE v_index INT DEFAULT 0;
    DECLARE v_count INT;
    DECLARE v_idrol INT;

    -- Actualizar la contraseña solo si no está vacía
    IF p_contrasena IS NOT NULL AND p_contrasena != '' THEN
        UPDATE usuario SET contrasena = p_contrasena WHERE email = p_email;
    END IF;

    -- Eliminar los roles anteriores
    DELETE FROM rol_usuario WHERE fkemail = p_email;

    -- Obtener el número de roles
    SET v_count = JSON_LENGTH(p_roles);

    -- Insertar los nuevos roles (formato: [{"fkidrol":1}, {"fkidrol":2}])
    WHILE v_index < v_count DO
        SET v_idrol = JSON_EXTRACT(p_roles, CONCAT('$[', v_index, '].fkidrol'));

        INSERT INTO rol_usuario (fkemail, fkidrol)
        VALUES (p_email, v_idrol);

        SET v_index = v_index + 1;
    END WHILE;
END$$

CREATE PROCEDURE eliminar_usuario_con_roles(
    IN p_email VARCHAR(100)
)
BEGIN
    -- Eliminar el usuario (los roles se eliminan automáticamente por ON DELETE CASCADE)
    DELETE FROM usuario WHERE email = p_email;
END$$

-- CORREGIDO: Formato unificado con los demás procedures de usuario
CREATE PROCEDURE actualizar_roles_usuario(
    IN p_email VARCHAR(100),
    IN p_roles_json JSON
)
BEGIN
    DECLARE v_index INT DEFAULT 0;
    DECLARE v_count INT;
    DECLARE v_idrol INT;

    -- Eliminar los roles anteriores
    DELETE FROM rol_usuario WHERE fkemail = p_email;

    -- Obtener el número de roles en el array JSON
    SET v_count = JSON_LENGTH(p_roles_json);

    -- Insertar los nuevos roles (formato: [{"fkidrol":1}, {"fkidrol":2}])
    WHILE v_index < v_count DO
        SET v_idrol = JSON_EXTRACT(p_roles_json, CONCAT('$[', v_index, '].fkidrol'));

        INSERT INTO rol_usuario (fkemail, fkidrol)
        VALUES (p_email, v_idrol);

        SET v_index = v_index + 1;
    END WHILE;
END$$

-- CORREGIDO para MariaDB 10.4: sin JSON_ARRAYAGG ni CAST AS JSON
CREATE PROCEDURE consultar_usuario_con_roles(
    IN p_email VARCHAR(100),
    OUT p_resultado JSON
)
BEGIN
    DECLARE v_roles_json TEXT;

    -- Construir el array JSON de roles usando GROUP_CONCAT
    SELECT CONCAT('[', COALESCE(GROUP_CONCAT(
        JSON_OBJECT('idrol', r.id, 'nombre', r.nombre)
    ), ''), ']')
    INTO v_roles_json
    FROM rol_usuario ru
    JOIN rol r ON r.id = ru.fkidrol
    WHERE ru.fkemail = p_email;

    -- Construir el resultado completo con CONCAT para anidar el array sin CAST
    SET p_resultado = CONCAT(
        '{"email":"', p_email, '"',
        ',"roles":', COALESCE(v_roles_json, '[]'),
        '}'
    );
END$$

-- CORREGIDO para MariaDB 10.4: sin JSON_ARRAYAGG ni CAST AS JSON
CREATE PROCEDURE listar_usuarios_con_roles(
    OUT p_resultado JSON
)
BEGIN
    DECLARE v_resultado TEXT;

    -- Construir el array de usuarios con sus roles usando CONCAT
    SELECT CONCAT('[', COALESCE(GROUP_CONCAT(
        CONCAT(
            '{"email":"', sub.email, '"',
            ',"roles":', COALESCE(sub.roles_json, '[]'),
            '}'
        )
    ), ''), ']')
    INTO v_resultado
    FROM (
        SELECT u.email,
            (SELECT CONCAT('[', COALESCE(GROUP_CONCAT(
                JSON_OBJECT('idrol', r.id, 'nombre', r.nombre)
            ), ''), ']')
            FROM rol_usuario ru
            JOIN rol r ON r.id = ru.fkidrol
            WHERE ru.fkemail = u.email
            ) AS roles_json
        FROM usuario u
    ) AS sub;

    SET p_resultado = COALESCE(v_resultado, '[]');
END$$

-- ================================================================
-- STORED PROCEDURES: Permisos (RBAC)
-- ================================================================
CREATE PROCEDURE verificar_acceso_ruta(
    IN p_email VARCHAR(100),
    IN p_fkidruta INT,
    OUT p_resultado JSON
)
BEGIN
    DECLARE v_tiene_acceso BOOLEAN DEFAULT FALSE;

    -- Verificar si el usuario tiene acceso a la ruta
    SELECT EXISTS(
        SELECT 1
        FROM usuario u
        INNER JOIN rol_usuario ur ON u.email = ur.fkemail
        INNER JOIN rutarol rr ON ur.fkidrol = rr.fkidrol
        WHERE u.email = p_email AND rr.fkidruta = p_fkidruta
    ) INTO v_tiene_acceso;

    -- Construir el resultado JSON
    SET p_resultado = JSON_OBJECT(
        'tiene_acceso', v_tiene_acceso,
        'email', p_email,
        'fkidruta', p_fkidruta
    );
END$$

CREATE PROCEDURE listar_rutarol()
BEGIN
    SELECT rr.fkidruta, rt.ruta, rr.fkidrol, r.nombre AS rol
    FROM rutarol rr
    JOIN ruta rt ON rt.id = rr.fkidruta
    JOIN rol r ON r.id = rr.fkidrol
    ORDER BY rt.ruta, r.nombre;
END$$

CREATE PROCEDURE crear_rutarol(
    IN p_fkidruta INT,
    IN p_fkidrol INT,
    OUT p_resultado JSON
)
BEGIN
    DECLARE v_existe_ruta INT;
    DECLARE v_existe_rol INT;
    DECLARE v_existe_permiso INT;

    -- Verificar si la ruta existe
    SELECT COUNT(*) INTO v_existe_ruta FROM ruta WHERE id = p_fkidruta;

    IF v_existe_ruta = 0 THEN
        SET p_resultado = JSON_OBJECT('success', false, 'message', 'La ruta especificada no existe');
    ELSE
        -- Verificar si el rol existe
        SELECT COUNT(*) INTO v_existe_rol FROM rol WHERE id = p_fkidrol;

        IF v_existe_rol = 0 THEN
            SET p_resultado = JSON_OBJECT('success', false, 'message', 'El rol especificado no existe');
        ELSE
            -- Verificar si el permiso ya existe
            SELECT COUNT(*) INTO v_existe_permiso FROM rutarol WHERE fkidruta = p_fkidruta AND fkidrol = p_fkidrol;

            IF v_existe_permiso > 0 THEN
                SET p_resultado = JSON_OBJECT('success', false, 'message', 'El permiso ya existe');
            ELSE
                INSERT INTO rutarol (fkidruta, fkidrol) VALUES (p_fkidruta, p_fkidrol);
                SET p_resultado = JSON_OBJECT('success', true, 'message', 'Permiso creado exitosamente');
            END IF;
        END IF;
    END IF;
END$$

CREATE PROCEDURE eliminar_rutarol(
    IN p_fkidruta INT,
    IN p_fkidrol INT,
    OUT p_resultado JSON
)
BEGIN
    DECLARE v_existe_permiso INT;

    -- Verificar si el permiso existe
    SELECT COUNT(*) INTO v_existe_permiso FROM rutarol WHERE fkidruta = p_fkidruta AND fkidrol = p_fkidrol;

    IF v_existe_permiso = 0 THEN
        SET p_resultado = JSON_OBJECT('success', false, 'message', 'El permiso no existe');
    ELSE
        DELETE FROM rutarol WHERE fkidruta = p_fkidruta AND fkidrol = p_fkidrol;
        SET p_resultado = JSON_OBJECT('success', true, 'message', 'Permiso eliminado exitosamente');
    END IF;
END$$

DELIMITER ;

-- ================================================================
-- DATOS INICIALES
-- ================================================================
INSERT INTO rol (nombre) VALUES
('Administrador'),
('Vendedor'),
('Cajero'),
('Contador'),
('Cliente');

INSERT INTO empresa (codigo, nombre) VALUES
('E001', 'Comercial Los Andes S.A.'),
('E002', 'Distribuciones El Centro S.A.');

INSERT INTO persona (codigo, nombre, email, telefono) VALUES
('P001', 'Ana Torres', 'ana.torres@correo.com', '3011111111'),
('P002', 'Carlos Pérez', 'carlos.perez@correo.com', '3022222222'),
('P003', 'María Gómez', 'maria.gomez@correo.com', '3033333333'),
('P004', 'Juan Díaz', 'juan.diaz@correo.com', '3044444444'),
('P005', 'Laura Rojas', 'laura.rojas@correo.com', '3055555555'),
('P006', 'Pedro Castillo', 'pedro.castillo@correo.com', '3066666666');

INSERT INTO cliente (credito, fkcodpersona, fkcodempresa) VALUES
(500000, 'P001', 'E001'),
(250000, 'P003', 'E002'),
(400000, 'P005', 'E001');

INSERT INTO vendedor (carnet, direccion, fkcodpersona) VALUES
(1001, 'Calle 10 #5-33', 'P002'),
(1002, 'Carrera 15 #7-20', 'P004'),
(1003, 'Avenida 30 #18-09', 'P006');

INSERT INTO producto (codigo, nombre, stock, valorunitario) VALUES
('PR001', 'Laptop Lenovo IdeaPad', 20, 2500000),
('PR002', 'Monitor Samsung 24"', 30, 800000),
('PR003', 'Teclado Logitech K380', 50, 150000),
('PR004', 'Mouse HP', 60, 90000),
('PR005', 'Impresora Epson EcoTank', 15, 1100000),
('PR006', 'Auriculares Sony WH-CH510', 25, 240000),
('PR007', 'Tablet Samsung Tab A9', 18, 950000),
('PR008', 'Disco Duro Seagate 1TB', 35, 280000);

-- Usuarios (formato JSON: [{"fkidrol":1}, {"fkidrol":2}])
CALL crear_usuario_con_roles('admin@correo.com', 'admin123', '[{"fkidrol":1}]');
CALL crear_usuario_con_roles('vendedor1@correo.com', 'vend123', '[{"fkidrol":2},{"fkidrol":3}]');
CALL crear_usuario_con_roles('jefe@correo.com', 'jefe123', '[{"fkidrol":1},{"fkidrol":3},{"fkidrol":4}]');
CALL crear_usuario_con_roles('cliente1@correo.com', 'cli123', '[{"fkidrol":5}]');

-- Facturas
CALL crear_factura_con_detalle(1, 1, '2025-10-15 00:00:00', '[{"fkcodproducto":"PR001","cantidad":1},{"fkcodproducto":"PR004","cantidad":2}]', 1);
CALL crear_factura_con_detalle(2, 2, '2025-10-16 00:00:00', '[{"fkcodproducto":"PR002","cantidad":2},{"fkcodproducto":"PR005","cantidad":1}]', 1);
CALL crear_factura_con_detalle(3, 3, '2025-10-17 00:00:00', '[{"fkcodproducto":"PR003","cantidad":3},{"fkcodproducto":"PR007","cantidad":1}]', 1);

-- Rutas del sistema
INSERT INTO ruta (ruta, descripcion) VALUES
('/home', 'Página principal - Dashboard'),
('/usuarios', 'Gestión de usuarios'),
('/facturas', 'Gestión de facturas'),
('/clientes', 'Gestión de clientes'),
('/vendedores', 'Gestión de vendedores'),
('/personas', 'Gestión de personas'),
('/empresas', 'Gestión de empresas'),
('/productos', 'Gestión de productos'),
('/roles', 'Gestión de roles'),
('/permisos', 'Gestión de permisos (asignación rol-ruta)'),
('/permisos/crear', 'Crear permiso (POST)'),
('/permisos/eliminar', 'Eliminar permiso (POST)'),
('/rutas', 'Gestión de rutas del sistema'),
('/rutas/crear', 'Crear ruta (POST)'),
('/rutas/eliminar', 'Eliminar ruta (POST)');

-- Rutas por rol (fkidruta, fkidrol)
-- Rutas: 1=/home,2=/usuarios,3=/facturas,4=/clientes,5=/vendedores,6=/personas,7=/empresas,8=/productos,9=/roles,10=/permisos,11=/permisos/crear,12=/permisos/eliminar,13=/rutas,14=/rutas/crear,15=/rutas/eliminar
-- Roles: 1=Administrador,2=Vendedor,3=Cajero,4=Contador,5=Cliente
INSERT INTO rutarol (fkidruta, fkidrol) VALUES
(1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1), (10, 1), (11, 1), (12, 1), (13, 1), (14, 1), (15, 1),
(1, 2), (3, 2), (4, 2),
(1, 3), (3, 3),
(1, 4), (4, 4), (8, 4),
(1, 5), (8, 5);

-- ================================================================
-- VERIFICACIÓN Y CONSULTAS DE EJEMPLO
-- ================================================================
-- Para verificar que todo está correcto:
-- SELECT * FROM factura;
-- SELECT * FROM productosporfactura;
-- SELECT * FROM producto;
-- CALL consultar_factura_con_detalle(1, @resultado);
-- SELECT @resultado;
