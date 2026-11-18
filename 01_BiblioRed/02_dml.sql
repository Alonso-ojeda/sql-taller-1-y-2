-- Datos de práctica y operaciones sobre registros | BiblioRed
-- Se mantienen los datos, reglas, orden de ejecución y salidas del taller.
-- Se reorganizaron los nombres internos y la presentación del SQL.

-- 02_dml.sql
-- Datos semilla, UPDATE/DELETE con SELECT previo, errores provocados.
-- Fecha de corte: 2026-11-10 (fija; es decir no se usa la del sistema
-- Los INSERT no escriben el id: se asigna solo, en el orden de inserción.
use bibliored;

-- Sedes (ids 1..5)
insert into branches (name, municipality, address, opened_on) values
('Sede Central Chía', 'Chía',      'Carrera 7 # 12-30',   '2012-03-15'),
('Sede Cajicá',       'Cajicá',    'Calle 3 # 5-20',      '2015-06-10'),
('Sede Zipaquirá',    'Zipaquirá', 'Carrera 9 # 4-15',    '2017-02-20'),
('Sede Cota',         'Cota',      'Avenida Principal 22','2020-08-05'),
('Sede Tabio',        'Tabio',     'Calle 5 # 3-10',      '2026-10-01');

-- Membresías (ids 1..5: Básica, Estudiante, Docente, Infantil, Institucional)
insert into memberships (name, max_loans, loan_days, max_renewals, daily_fine, annual_fee) values
('Básica',        2, 14, 1,  500.00,      0.00),
('Estudiante',    3, 14, 2,  300.00,      0.00),
('Docente',       5, 21, 2,  300.00,  30000.00),
('Infantil',      2,  7, 1,  200.00,      0.00),
('Institucional',10, 30, 3, 1000.00, 250000.00);

-- Categorías (ids 1..8; Cómic = 8 queda sin títulos)
insert into categories (name) values
('Novela'), ('Cuento'), ('Poesía'), ('Historia'), ('Ciencia'), ('Infantil'), ('Referencia'), ('Cómic');

-- Empleados (ids 1..6). El 5 se inserta SIN rol para comprobar el DEFAULT.
insert into employees (full_name, email, hire_date, role, branch_id) values
('Patricia Lemus',      'patricia.lemus@bibliored.test', '2012-03-15', 'COORDINADOR',   1),
('Andrés Rojas',        'andres.rojas@bibliored.test',   '2014-01-20', 'BIBLIOTECARIO', 1),
('Luisa Mora',          'luisa.mora@bibliored.test',     '2015-06-10', 'BIBLIOTECARIO', 2),
('Camilo Ortiz',        'camilo.ortiz@bibliored.test',   '2017-02-20', 'BIBLIOTECARIO', 3);

insert into employees (full_name, email, hire_date, branch_id) values
('Marta Beltrán',       'marta.beltran@bibliored.test',  '2020-08-05', 4);

insert into employees (full_name, email, hire_date, role, branch_id) values
('Diego Pardo',         'diego.pardo@bibliored.test',    '2026-10-01', 'AUXILIAR',      5);

-- Editoriales (ids 1..7). La 6 queda sin títulos (D1); la 7 se borra en el DELETE.
insert into publishers (name, city) values
('Editorial Sabana',    'Bogotá'),
('Ediciones Andinas',   'Medellín'),
('Páramo Libros',       'Bogotá'),
('Editorial Cóndor',    'Cali'),
('Luna Nueva',          'Bogotá'),
('Casa del Sur',        'Bucaramanga'),
('Imprenta Cordillera', 'Tunja');

-- Autores (ids 1..10). El 10 queda sin títulos (D1).
insert into authors (full_name, nationality, birth_year) values
('Laura Gómez Ortega',     'Colombiana', 1975),
('Mateo Herrera Ruiz',     'Colombiana', 1968),
('Elena Vargas Prieto',    'Colombiana', 1982),
('Carlos Duarte León',     'Colombiana', 1959),
('Sofía Marín Cano',       'Chilena',    1971),
('Julián Peña Torres',     'Argentina',  1964),
('Ana Lucía Roldán',       'Colombiana', 1990),
('Tomás Quiroga Bell',     'Peruana',    1955),
('Valentina Ríos Mejía',   'Colombiana', 1986),
('Ignacio Salazar Pinto',  'Española',   1949);

-- Títulos (ids 1..14). DEFAULT = costo $50.000 (D13) en los títulos 3, 5 y 9.
-- El título 14 no tiene ejemplares (D1).
insert into titles (isbn, name, publication_year, replacement_cost, category_id, publisher_id) values
('978-958-0001-01-1', 'Cuentos de la Sabana',              2019, 45000.00, 2, 1),
('978-958-0001-02-8', 'Átomos para curiosos',              2020, 68000.00, 5, 3),
('978-958-0001-03-5', 'La casa del páramo',                2016, default,  1, 2),
('978-958-0001-04-2', 'Historia breve de la Sabana',       2014, 55000.00, 4, 1),
('978-958-0001-05-9', 'Versos de la niebla',               2018, default,  3, 3),
('978-958-0001-06-6', 'El mapa de los ríos',               2021, 52000.00, 1, 4),
('978-958-0001-07-3', 'Diccionario práctico del español',  2010, 90000.00, 7, 2),
('978-958-0001-08-0', 'Cuentos para dormir el sol',        2022, 38000.00, 6, 5),
('978-958-0001-09-7', 'El universo en una gota',           2023, default,  5, 5),
('978-958-0001-10-3', 'Crónicas del Muisca',               2012, 60000.00, 4, 2),
('978-958-0001-11-0', 'Poemas para un jardín',             2020, 40000.00, 3, 3),
('978-958-0001-12-7', 'La ciudad sin relojes',             2024, 58000.00, 1, 4),
('978-958-0001-13-4', 'Atlas ilustrado de Colombia',       2017, 85000.00, 7, 1),
('978-958-0001-14-1', 'El cartero de las estrellas',       2025, 36000.00, 6, 1);

-- Autores por título (título, autor, orden). Títulos 1, 4 y 6 con dos autores (D2).
insert into title_authors (title_id, author_id, author_order) values
(1, 1, 1), (1, 2, 2),
(2, 3, 1),
(3, 4, 1),
(4, 2, 1), (4, 6, 2),
(5, 5, 1),
(6, 7, 1), (6, 9, 2),
(7, 8, 1),
(8, 1, 1),
(9, 3, 1),
(10, 6, 1),
(11, 5, 1),
(12, 4, 1),
(13, 9, 1),
(14, 7, 1);

-- Ejemplares (ids 1..25): (código, adquirido, estado, título, sede)
-- Chía 1-9 · Cajicá 10-15 · Zipaquirá 16-20 · Cota 21-25 · Tabio ninguno.
-- Ejemplar 16 (Zipaquirá, 2011) es el más antiguo de la red.
-- Ejemplar 21 (Cota, Átomos para curiosos) está PERDIDO.
insert into copies (barcode, acquired_on, status, title_id, branch_id) values
('BR-0001', '2019-05-10', 'DISPONIBLE',    1, 1),
('BR-0002', '2019-05-10', 'PRESTADO',      1, 1),
('BR-0003', '2020-09-01', 'PRESTADO',      2, 1),
('BR-0004', '2016-04-12', 'DISPONIBLE',    3, 1),
('BR-0005', '2014-07-20', 'PRESTADO',      4, 1),
('BR-0006', '2018-03-03', 'DISPONIBLE',    5, 1),
('BR-0007', '2012-05-05', 'DISPONIBLE',    7, 1),
('BR-0008', '2023-06-15', 'PRESTADO',      9, 1),
('BR-0009', '2024-02-20', 'PRESTADO',     12, 1),
('BR-0010', '2019-06-01', 'PRESTADO',      1, 2),
('BR-0011', '2016-05-01', 'PRESTADO',      3, 2),
('BR-0012', '2021-04-18', 'PRESTADO',      6, 2),
('BR-0013', '2022-08-09', 'DISPONIBLE',    8, 2),
('BR-0014', '2013-02-11', 'PRESTADO',     10, 2),
('BR-0015', '2020-11-30', 'EN_REPARACION',11, 2),
('BR-0016', '2011-03-14', 'DISPONIBLE',    4, 3),
('BR-0017', '2012-09-09', 'PRESTADO',      7, 3),
('BR-0018', '2022-08-09', 'EN_REPARACION', 8, 3),
('BR-0019', '2013-10-10', 'DISPONIBLE',   10, 3),
('BR-0020', '2017-12-01', 'PRESTADO',     13, 3),
('BR-0021', '2020-09-01', 'PERDIDO',       2, 4),
('BR-0022', '2021-01-15', 'DISPONIBLE',    2, 4),
('BR-0023', '2021-04-18', 'PRESTADO',      6, 4),
('BR-0024', '2023-06-15', 'DADO_DE_BAJA',  9, 4),
('BR-0025', '2018-02-02', 'DISPONIBLE',   13, 4);

-- Socios (ids 1..14). Ricardo (12) sin teléfono; 13 es el único de Tabio.
-- Nadie con membresía 5 (Institucional).
insert into members (document_number, first_name, last_name, email, phone, birth_date, joined_on, status, membership_id, branch_id) values
('1001001001', 'Camila',    'Torres Beltrán', 'camila.torres@correo.test',   '3001110001', '2004-05-20', '2024-02-10', 'ACTIVO',     2, 1),
('1001001002', 'Juan David','Pérez Salas',    'juan.perez@correo.test',      '3001110002', '1985-09-14', '2023-05-02', 'ACTIVO',     1, 1),
('1001001003', 'Marcela',   'Ruiz Gómez',     'marcela.ruiz@correo.test',    '3001110003', '1979-01-30', '2022-08-15', 'ACTIVO',     3, 2),
('1001001004', 'Sebastián', 'Acosta Vega',    null,                          null,         '2016-03-12', '2025-03-01', 'ACTIVO',     4, 2),
('1001001005', 'Valeria',   'Castro Pinto',   null,                          null,         '2015-11-02', '2025-04-12', 'ACTIVO',     4, 1),
('1001001006', 'Óscar',     'Mendoza Leal',   'oscar.mendoza@correo.test',   '3001110006', '1990-07-07', '2023-11-20', 'SUSPENDIDO', 1, 2),
('1001001007', 'Natalia',   'Rincón Soto',    'natalia.rincon@correo.test',  '3001110007', '2003-12-01', '2024-09-05', 'ACTIVO',     2, 3),
('1001001008', 'Felipe',    'Cárdenas Mora',  'felipe.cardenas@correo.test', '3001110008', '1995-04-22', '2024-01-18', 'ACTIVO',     1, 3),
('1001001009', 'Daniela',   'Ospina Reyes',   'daniela.ospina@correo.test',  '3001110009', '1982-10-09', '2021-07-01', 'ACTIVO',     3, 1),
('1001001010', 'Héctor',    'Salgado Vega',   'hector.salgado@correo.test',  '3001110010', '1970-02-02', '2020-10-10', 'INACTIVO',   1, 4),
('1001001011', 'Lorena',    'Bautista Díaz',  'lorena.bautista@correo.test', '3001110011', '2002-06-18', '2023-03-03', 'ACTIVO',     2, 4),
('1001001012', 'Ricardo',   'Neira Cruz',     'ricardo.neira@correo.test',   null,         '1988-08-08', '2026-10-20', 'ACTIVO',     1, 3),
('1001001013', 'Isabel',    'Guerrero Lara',  'isabel.guerrero@correo.test', '3001110013', '2005-09-09', '2026-10-05', 'ACTIVO',     2, 5),
('1001001014', 'Pablo',     'Giraldo Ríos',   'pablo.giraldo@correo.test',   '3001110014', '2001-03-15', '2025-02-14', 'ACTIVO',     2, 1);

-- Préstamos (ids 1001..1022): (ejemplar, socio, empleado, fecha, vence, devuelto, estado)
-- vence = fecha + días de la membresía del socio.
-- 1001-1009 devueltos · 1010-1021 activos · 1022 perdido.
insert into loans (copy_id, member_id, employee_id, loaned_on, due_on, returned_on, status) values
(7,  1,  1, '2026-09-02', '2026-09-16', '2026-09-15', 'DEVUELTO'),  -- 1001 a tiempo
(4,  2,  2, '2026-09-03', '2026-09-17', '2026-09-25', 'DEVUELTO'),  -- 1002 tarde 8 días
(13, 4,  3, '2026-09-08', '2026-09-15', '2026-09-14', 'DEVUELTO'),  -- 1003 a tiempo
(16, 7,  4, '2026-09-10', '2026-09-24', '2026-09-20', 'DEVUELTO'),  -- 1004 a tiempo
(1,  9,  1, '2026-09-12', '2026-10-03', '2026-10-10', 'DEVUELTO'),  -- 1005 tarde 7 días
(19, 6,  4, '2026-09-15', '2026-09-29', '2026-10-05', 'DEVUELTO'),  -- 1006 tarde 6 días
(25, 3,  5, '2026-09-20', '2026-10-11', '2026-10-13', 'DEVUELTO'),  -- 1007 tarde 2 días
(22, 14, 5, '2026-09-22', '2026-10-06', '2026-10-11', 'DEVUELTO'),  -- 1008 tarde 5 días
(6,  10, 2, '2026-09-18', '2026-10-02', '2026-10-01', 'DEVUELTO'),  -- 1009 a tiempo
(11, 6,  3, '2026-10-02', '2026-10-16', null,         'ACTIVO'),    -- 1010 vencido (Cajicá)
(14, 3,  3, '2026-10-05', '2026-10-26', null,         'ACTIVO'),    -- 1011 vencido (Cajicá)
(12, 4,  3, '2026-11-06', '2026-11-13', null,         'ACTIVO'),    -- 1012 al día
(10, 1,  3, '2026-10-27', '2026-11-10', null,         'ACTIVO'),    -- 1013 vence el día del corte
(2,  8,  2, '2026-10-27', '2026-11-10', null,         'ACTIVO'),    -- 1014 vence el día del corte (D7: Felipe, 1.º)
(17, 8,  4, '2026-11-02', '2026-11-16', null,         'ACTIVO'),    -- 1015 (D7: Felipe, 2.º; título 7 con reserva, D9)
(3,  1,  1, '2026-10-06', '2026-11-17', null,         'ACTIVO'),    -- 1016 con 2 renovaciones (agotó)
(8,  9,  2, '2026-10-20', '2026-12-01', null,         'ACTIVO'),    -- 1017 con 1 renovación
(5,  7,  1, '2026-10-15', '2026-10-29', null,         'ACTIVO'),    -- 1018 vencido (Chía)
(9,  9,  2, '2026-11-03', '2026-11-24', null,         'ACTIVO'),    -- 1019
(20, 2,  4, '2026-11-05', '2026-11-19', null,         'ACTIVO'),    -- 1020
(23, 5,  5, '2026-11-04', '2026-11-11', null,         'ACTIVO'),    -- 1021
(21, 11, 5, '2026-09-05', '2026-09-19', null,         'PERDIDO');   -- 1022 Átomos para curiosos perdido

-- Renovaciones (3): préstamo 1016 (dos) y 1017 (una)
insert into loan_renewals (loan_id, renewed_on, previous_due_on, new_due_on) values
(1016, '2026-10-18', '2026-10-20', '2026-11-03'),
(1016, '2026-11-02', '2026-11-03', '2026-11-17'),
(1017, '2026-11-03', '2026-11-10', '2026-12-01');

-- Reservas (ids 1..7), cuatro estados.
-- 1: PENDIENTE entregable (hay ejemplar 7 DISPONIBLE del título 7 en Chía)
-- 2: PENDIENTE ya expirada (pasará a VENCIDA en el UPDATE)
-- 3 y 4: PENDIENTE en espera · 5: ATENDIDA · 6 y 7: CANCELADA (la 6 se borra)
insert into reservations (member_id, title_id, branch_id, reserved_on, expires_on, status) values
(12, 7,  1, '2026-11-04', '2026-11-14', 'PENDIENTE'),
(5,  3,  2, '2026-10-01', '2026-10-08', 'PENDIENTE'),
(2,  12, 1, '2026-11-02', '2026-11-20', 'PENDIENTE'),
(3,  6,  4, '2026-11-05', '2026-11-19', 'PENDIENTE'),
(1,  5,  1, '2026-09-20', '2026-09-30', 'ATENDIDA'),
(14, 9,  5, '2026-10-12', '2026-10-22', 'CANCELADA'),
(9,  10, 3, '2026-10-15', '2026-10-25', 'CANCELADA');

-- Multas (ids 1..6): valor = días × multa por día de la membresía (regla 18)
-- 1 PAGADA (1 cuota) · 2 PAGADA (2 cuotas) · 3 PENDIENTE sin abonos (Óscar, suspendido)
-- 4 PENDIENTE con abono parcial (PERDIDA, Lorena) · 5 ANULADA · 6 PENDIENTE sin abonos (Marcela)
insert into fines (loan_id, reason, status, late_days, amount, issued_on) values
(1002, 'MORA',    'PAGADA',    8,  4000.00, '2026-09-25'),
(1005, 'MORA',    'PAGADA',    7,  2100.00, '2026-10-10'),
(1006, 'MORA',    'PENDIENTE', 6,  3000.00, '2026-10-05'),
(1022, 'PERDIDA', 'PENDIENTE', 0, 68000.00, '2026-10-01'),
(1008, 'MORA',    'ANULADA',   5,  1500.00, '2026-10-11'),
(1007, 'MORA',    'PENDIENTE', 2,   600.00, '2026-10-13');

-- Cuotas de multas (4)
insert into fine_payments (fine_id, amount, paid_on, payment_method) values
(1,  4000.00, '2026-09-26', 'EFECTIVO'),
(2,  1000.00, '2026-10-11', 'EFECTIVO'),
(2,  1100.00, '2026-10-15', 'TARJETA'),
(4, 20000.00, '2026-10-20', 'TRANSFERENCIA');

-- UPDATE con SELECT previo y SELECT de comprobación
-- U1. Un ejemplar EN_REPARACION vuelve al estante (ejemplar 15)
select id, barcode, status from copies where id = 15;
update copies set status = 'DISPONIBLE' where id = 15;
select id, barcode, status from copies where id = 15;

-- U2. Reservas PENDIENTE que expiraron antes del corte pasan a VENCIDA
-- (id > 0 permite pasar Safe Updates: el WHERE usa la clave primaria)
select id, member_id, title_id, expires_on, status from reservations
where id > 0 and status = 'PENDIENTE' and expires_on < '2026-11-10';
update reservations set status = 'VENCIDA'
where id > 0 and status = 'PENDIENTE' and expires_on < '2026-11-10';
select id, member_id, title_id, expires_on, status from reservations order by id;

-- U3. La cuota anual de la membresía Docente sube 10 % (30.000 -> 33.000)
select id, name, annual_fee from memberships where name = 'Docente';
update memberships set annual_fee = round(annual_fee * 1.10, 2) where name = 'Docente';
select id, name, annual_fee from memberships where name = 'Docente';

-- U4. Un socio registra su celular (Ricardo, id 12)
select id, first_name, phone from members where id = 12;
update members set phone = '3105550112' where id = 12;
select id, first_name, phone from members where id = 12;

-- DELETE con SELECT previo
-- D-a. Borrar una reserva CANCELADA (id 6)
select id, member_id, title_id, status from reservations where id = 6;
delete from reservations where id = 6;
select id from reservations where id = 6;   -- debe quedar vacío

-- D-b. Borrar la editorial sin títulos (id 7). Primero comprobar que no tiene títulos:
select count(*) as titulos_de_la_editorial from titles where publisher_id = 7;   -- debe dar 0
select id, name from publishers where id = 7;
delete from publishers where id = 7;
select id, name from publishers order by id;   -- quedan 6; Casa del Sur (6) sigue sin títulos

-- TRES ERRORES PROVOCADOS
-- E1 (caso 9): código de barras repetido
-- ESPERADO: ERROR 1062 (23000): Duplicate entry 'BR-0001' for key 'copies.barcode'
-- Lo produce el UNIQUE de copies.barcode.
-- INSERT INTO copies (barcode, acquired_on, title_id, branch_id) VALUES ('BR-0001', '2026-11-01', 1, 1);

-- E2 (caso 12): cuota de $0
-- ESPERADO: ERROR 3819 (HY000): Check constraint 'fine_payments_chk_1' is violated.
-- Lo produce el CHECK (amount > 0) de fine_payments.
-- INSERT INTO fine_payments (fine_id, amount, paid_on, payment_method) VALUES (3, 0, '2026-11-10', 'EFECTIVO');

-- E3 (caso 15): borrar una editorial que tiene títulos
-- ESPERADO: ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails
-- Lo produce la FK titles.publisher_id -> publishers.id (sin CASCADE: regla 22).
-- DELETE FROM publishers WHERE id = 1;

-- VERIFICACIÓN FINAL
-- Conteo de filas por tabla (esperado entre paréntesis)
select 'branches' as tabla, count(*) as filas from branches            -- 5
union all select 'memberships',   count(*) from memberships            -- 5
union all select 'categories',    count(*) from categories             -- 8
union all select 'employees',     count(*) from employees              -- 6
union all select 'publishers',    count(*) from publishers             -- 6
union all select 'authors',       count(*) from authors                -- 10
union all select 'titles',        count(*) from titles                 -- 14
union all select 'title_authors', count(*) from title_authors          -- 17
union all select 'copies',        count(*) from copies                 -- 25
union all select 'members',       count(*) from members                -- 14
union all select 'loans',         count(*) from loans                  -- 22
union all select 'loan_renewals', count(*) from loan_renewals          -- 3
union all select 'reservations',  count(*) from reservations           -- 6
union all select 'fines',         count(*) from fines                  -- 6
union all select 'fine_payments', count(*) from fine_payments;         -- 4

-- Caso D14: cada ejemplar PRESTADO tiene un préstamo ACTIVO y viceversa (ambas columnas deben dar 0)
select
    (select count(*) from copies ref_c
      where ref_c.status = 'PRESTADO'
        and not exists (select 1 from loans ref_l where ref_l.copy_id = ref_c.id and ref_l.status = 'ACTIVO')) as prestados_sin_prestamo,
    (select count(*) from loans ref_l join copies ref_c on ref_c.id = ref_l.copy_id
      where ref_l.status = 'ACTIVO' and ref_c.status <> 'PRESTADO') as activos_sin_ejemplar_prestado;