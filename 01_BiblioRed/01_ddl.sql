-- Estructura relacional y restricciones | BiblioRed
-- Se mantienen los datos, reglas, orden de ejecución y salidas del taller.
-- Se reorganizaron los nombres internos y la presentación del SQL.

-- 01_ddl.sql
drop database if exists bibliored;
create database bibliored;
use bibliored;

-- Tablas sin dependencias
-- Regla 1: sedes con nombre único
create table branches (
    id bigint auto_increment primary key,
    name varchar(100) not null unique,
    municipality varchar(60) not null,
    address varchar(120) not null,
    opened_on date not null
);

-- Regla 4: categorías con nombre único
create table categories (
    id bigint auto_increment primary key,
    name varchar(60) not null unique
);

-- Regla 4: editoriales con nombre único y ciudad
create table publishers (
    id bigint auto_increment primary key,
    name varchar(100) not null unique,
    city varchar(60) not null
);

-- Regla 5: autores
create table authors (
    id bigint auto_increment primary key,
    full_name varchar(120) not null,
    nationality varchar(60) not null,
    birth_year smallint not null
);

-- Regla 7: membresías (topes y tarifas con CHECK)
create table memberships (
    id bigint auto_increment primary key,
    name varchar(40) not null unique,
    max_loans int not null,
    loan_days int not null,
    max_renewals int not null,
    daily_fine decimal(10,2) not null,
    annual_fee decimal(12,2) not null,
    check (max_loans > 0),
    check (loan_days > 0),
    check (max_renewals >= 0),
    check (daily_fine >= 0),
    check (annual_fee >= 0)
);

-- Tablas que dependen de las anteriores
-- Regla 2: empleado en una sola sede, correo único, rol por defecto BIBLIOTECARIO
create table employees (
    id bigint auto_increment primary key,
    full_name varchar(120) not null,
    email varchar(100) not null unique,
    hire_date date not null,
    role enum('COORDINADOR', 'BIBLIOTECARIO', 'AUXILIAR') not null default 'BIBLIOTECARIO',
    branch_id bigint not null,
    foreign key (branch_id) references branches(id)
);

-- Regla 3: título con ISBN único, una categoría, una editorial, costo por defecto 50.000
create table titles (
    id bigint auto_increment primary key,
    isbn varchar(20) not null unique,
    name varchar(150) not null,
    publication_year smallint not null,
    replacement_cost decimal(12,2) not null default 50000.00,
    category_id bigint not null,
    publisher_id bigint not null,
    foreign key (category_id) references categories(id),
    foreign key (publisher_id) references publishers(id)
);

-- Regla 5: tabla puente título-autor con orden de autoría
create table title_authors (
    id bigint auto_increment primary key,
    title_id bigint not null,
    author_id bigint not null,
    author_order int not null,
    foreign key (title_id) references titles(id),
    foreign key (author_id) references authors(id),
    unique (title_id, author_id),
    unique (title_id, author_order),
    check (author_order >= 1)
);

-- Regla 6: ejemplar físico con código de barras único y estado
create table copies (
    id bigint auto_increment primary key,
    barcode varchar(30) not null unique,
    acquired_on date not null,
    status enum('DISPONIBLE', 'PRESTADO', 'EN_REPARACION', 'PERDIDO', 'DADO_DE_BAJA') not null default 'DISPONIBLE',
    title_id bigint not null,
    branch_id bigint not null,
    foreign key (title_id) references titles(id),
    foreign key (branch_id) references branches(id)
);

-- Regla 8: socio (correo y teléfono pueden ser NULL; documento y correo únicos)
create table members (
    id bigint auto_increment primary key,
    document_number varchar(20) not null unique,
    first_name varchar(60) not null,
    last_name varchar(60) not null,
    email varchar(100) unique,
    phone varchar(20),
    birth_date date not null,
    joined_on date not null,
    status enum('ACTIVO', 'SUSPENDIDO', 'INACTIVO') not null default 'ACTIVO',
    membership_id bigint not null,
    branch_id bigint not null,
    foreign key (membership_id) references memberships(id),
    foreign key (branch_id) references branches(id)
);

-- Reglas 9 y 10: préstamo (devolución vacía mientras no vuelva; numeración desde 1001)
create table loans (
    id bigint auto_increment primary key,
    loaned_on date not null,
    due_on date not null,
    returned_on date,
    status enum('ACTIVO', 'DEVUELTO', 'PERDIDO') not null default 'ACTIVO',
    copy_id bigint not null,
    member_id bigint not null,
    employee_id bigint not null,
    foreign key (copy_id) references copies(id),
    foreign key (member_id) references members(id),
    foreign key (employee_id) references employees(id),
    check (due_on > loaned_on),
    check (returned_on is null or returned_on >= loaned_on)
) auto_increment = 1001;

-- Regla 14: historial de renovaciones
create table loan_renewals (
    id bigint auto_increment primary key,
    renewed_on date not null,
    previous_due_on date not null,
    new_due_on date not null,
    loan_id bigint not null,
    foreign key (loan_id) references loans(id),
    check (new_due_on > previous_due_on)
);

-- Regla 16: reserva sobre un título, con sede de recogida propia
create table reservations (
    id bigint auto_increment primary key,
    reserved_on date not null,
    expires_on date not null,
    status enum('PENDIENTE', 'ATENDIDA', 'CANCELADA', 'VENCIDA') not null default 'PENDIENTE',
    member_id bigint not null,
    title_id bigint not null,
    branch_id bigint not null,
    foreign key (member_id) references members(id),
    foreign key (title_id) references titles(id),
    foreign key (branch_id) references branches(id),
    check (expires_on >= reserved_on)
);

-- Reglas 17 y 18: multa que nace de un préstamo; el valor se guarda y no cambia
create table fines (
    id bigint auto_increment primary key,
    reason enum('MORA', 'DAÑO', 'PERDIDA') not null,
    status enum('PENDIENTE', 'PAGADA', 'ANULADA') not null default 'PENDIENTE',
    late_days int not null default 0,
    amount decimal(12,2) not null,
    issued_on date not null,
    loan_id bigint not null,
    foreign key (loan_id) references loans(id),
    check (late_days >= 0),
    check (amount > 0)
);

-- Regla 20: cuotas de una multa
create table fine_payments (
    id bigint auto_increment primary key,
    amount decimal(12,2) not null,
    paid_on date not null,
    payment_method enum('EFECTIVO', 'TARJETA', 'TRANSFERENCIA') not null,
    fine_id bigint not null,
    foreign key (fine_id) references fines(id),
    check (amount > 0)
);

-- Verificación
show TABLES;
DESCRIBE loans;

-- REGLAS QUE NO SE PUEDEN PROTEGER SOLO CON LA ESTRUCTURA
-- (PK, FK, UNIQUE, CHECK, NOT NULL). Para cada una: por qué no cabe y dónde se resuelve.
--  Un CHECK solo ve las columnas de la fila que se guarda; no puede
-- consultar otras filas, otras tablas ni "la fecha de hoy".
-- Regla 10 (vencimiento = fecha del préstamo + días de la membresía)
--   Por qué no cabe: los días están en memberships, otra tabla; el CHECK no la ve.
--   Se resuelve en: fase 5 (sp_prestar_ejemplar calcula el vencimiento y
--   sp_renovar_prestamo el nuevo vencimiento).
-- Regla 11 (prestar solo a socio ACTIVO, sin multas y bajo el tope)
--   Por qué no cabe: hay que contar filas de fines y loans; un CHECK no hace subconsultas.
--   Se resuelve en: fase 5 (sp_prestar_ejemplar).
-- Regla 12 (ejemplar PRESTADO <=> préstamo ACTIVO)
--   Por qué no cabe: compara el estado de dos tablas (copies y loans); ningún CHECK ni
--   FK compara el valor de una columna con el de otra tabla.
--   Se resuelve en: fase 5 (los procedimientos cambian ejemplar y préstamo) y fase 6
--   (la transacción hace que ambos cambios ocurran juntos o ninguno).
-- Regla 15 (renovar solo si está activo, sin vencer, sin agotar renovaciones y sin reservas)
--   Por qué no cabe: depende de conteos en otras tablas y de una fecha de referencia.
--   Se resuelve en: fase 5 (sp_renovar_prestamo).
-- Regla 16, 2.ª parte (una reserva PENDIENTE ya expirada debe quedar VENCIDA)
--   Por qué no cabe: un CHECK no puede depender de "hoy"; es una acción que alguien
--   ejecuta con una fecha de corte, no una condición de una fila.
--   Se resuelve en: el enunciado la deja para la fase 5; aquí se hace con el UPDATE
--   de mantenimiento de la fase 3 (02_dml.sql, U2) y con el reto R3.
-- Regla 18 (multa por mora = días de retraso × multa por día de la membresía)
--   Por qué no cabe: es un cálculo con datos de memberships y de la fecha de devolución.
--   Se resuelve en: fase 5 (sp_devolver_ejemplar).
-- Regla 19 (libro perdido => préstamo y ejemplar PERDIDO + multa PERDIDA por el costo de reposición)
--   Por qué no cabe: es un efecto en cadena sobre varias tablas (loans, copies, fines).
--   Se resuelve en: los datos de la fase 3 (así lo indica el enunciado para este taller).
-- Regla 20, tope de la cuota y paso a PAGADA
--   Por qué no cabe: el saldo es una suma sobre otra tabla (fine_payments) y el paso a
--   PAGADA es un cambio en fines que depende de esa suma; un CHECK solo ve una fila.
--   Se resuelve en: fase 5 (sp_pagar_multa).