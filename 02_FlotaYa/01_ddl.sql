-- Estructura relacional y restricciones | FlotaYa
-- Se mantienen los datos, reglas, orden de ejecución y salidas del taller.
-- Se reorganizaron los nombres internos y la presentación del SQL.

-- 01_ddl.sql
drop database if exists flotaya;
create database flotaya;
use flotaya;

-- 1. Geografía y personal

create table departments (
    id bigint auto_increment primary key,
    name varchar(80) not null unique
);

create table cities (
    id bigint auto_increment primary key,
    department_id bigint not null,
    name varchar(80) not null,
    unique (department_id, name),
    foreign key (department_id) references departments(id)
);

create table branches (
    id bigint auto_increment primary key,
    city_id bigint not null,
    name varchar(120) not null unique,
    address varchar(160) not null,
    phone varchar(20) null,
    is_airport boolean not null default false,
    foreign key (city_id) references cities(id)
);

create table employees (
    id bigint auto_increment primary key,
    branch_id bigint not null,
    full_name varchar(120) not null,
    email varchar(120) not null unique,
    hire_date date not null,
    role enum('ADMINISTRADOR', 'ASESOR', 'INSPECTOR', 'MECANICO') not null,
    foreign key (branch_id) references branches(id)
);


-- 2. Flota y precios


create table categories (
    id bigint auto_increment primary key,
    name varchar(40) not null unique,
    min_age int not null,
    deposit_amount decimal(12,2) not null,
    check (min_age >= 18),
    check (deposit_amount >= 0)
);

create table brands (
    id bigint auto_increment primary key,
    name varchar(60) not null unique
);

create table models (
    id bigint auto_increment primary key,
    brand_id bigint not null,
    category_id bigint not null,
    name varchar(80) not null,
    transmission enum('MECANICA', 'AUTOMATICA') not null,
    fuel enum('GASOLINA', 'DIESEL', 'HIBRIDO', 'ELECTRICO') not null,
    seats int not null,
    unique (brand_id, name),
    check (seats > 0),
    foreign key (brand_id) references brands(id),
    foreign key (category_id) references categories(id)
);

create table vehicles (
    id bigint auto_increment primary key,
    model_id bigint not null,
    plate varchar(6) not null unique,
    model_year smallint not null,
    color varchar(30) not null,
    mileage_km int not null default 0,
    status enum('DISPONIBLE', 'ALQUILADO', 'MANTENIMIENTO', 'FUERA_DE_SERVICIO') not null default 'DISPONIBLE',
    branch_id bigint not null,
    check (mileage_km >= 0),
    check (model_year between 1990 and 2100),
    foreign key (model_id) references models(id),
    foreign key (branch_id) references branches(id)
);

create table seasons (
    id bigint auto_increment primary key,
    name varchar(80) not null unique,
    season_type enum('BAJA', 'MEDIA', 'ALTA') not null,
    start_date date not null,
    end_date date not null,
    check (end_date >= start_date)
);

create table season_rates (
    id bigint auto_increment primary key,
    category_id bigint not null,
    season_type enum('BAJA', 'MEDIA', 'ALTA') not null,
    daily_rate decimal(12,2) not null,
    unique (category_id, season_type),
    check (daily_rate > 0),
    foreign key (category_id) references categories(id)
);

create table maintenances (
    id bigint auto_increment primary key,
    vehicle_id bigint not null,
    maintenance_type enum('PREVENTIVO', 'CORRECTIVO', 'LATONERIA') not null,
    description varchar(200) not null,
    workshop varchar(120) not null,
    start_date date not null,
    end_date date null,
    cost decimal(12,2) null,
    check (end_date is null or end_date >= start_date),
    check (cost is null or cost >= 0),
    foreign key (vehicle_id) references vehicles(id)
);

create table extras (
    id bigint auto_increment primary key,
    name varchar(60) not null unique,
    daily_price decimal(12,2) not null,
    check (daily_price > 0)
);


-- 3. Clientes y conductores


create table customers (
    id bigint auto_increment primary key,
    document_type enum('CC', 'CE', 'PASAPORTE') not null default 'CC',
    document_number varchar(20) not null unique,
    first_name varchar(60) not null,
    last_name varchar(60) not null,
    email varchar(120) not null unique,
    phone varchar(20) null,
    birth_date date not null,
    city_id bigint not null,
    registered_at datetime not null default CURRENT_TIMESTAMP,
    status enum('ACTIVO', 'BLOQUEADO') not null default 'ACTIVO',
    foreign key (city_id) references cities(id)
);

create table driver_licenses (
    id bigint auto_increment primary key,
    customer_id bigint not null,
    license_number varchar(30) not null unique,
    category enum('B1', 'B2', 'C1', 'C2') not null,
    issue_date date not null,
    expiry_date date not null,
    country varchar(60) not null default 'Colombia',
    check (expiry_date > issue_date),
    foreign key (customer_id) references customers(id)
);

create table additional_drivers (
    id bigint auto_increment primary key,
    document_number varchar(20) not null unique,
    full_name varchar(120) not null,
    birth_date date not null,
    license_number varchar(30) not null unique,
    license_expiry_date date not null
);


-- 4. Reservas y contratos


create table reservations (
    id bigint auto_increment primary key,
    customer_id bigint not null,
    vehicle_id bigint not null,
    pickup_branch_id bigint not null,
    return_branch_id bigint not null,
    pickup_date date not null,
    return_date date not null,
    quoted_value decimal(12,2) not null,
    created_at datetime not null default CURRENT_TIMESTAMP,
    status enum('PENDIENTE', 'CONFIRMADA', 'CONVERTIDA', 'CANCELADA') not null default 'PENDIENTE',
    check (return_date > pickup_date),
    check (quoted_value >= 0),
    foreign key (customer_id) references customers(id),
    foreign key (vehicle_id) references vehicles(id),
    foreign key (pickup_branch_id) references branches(id),
    foreign key (return_branch_id) references branches(id)
) auto_increment = 501;

create table contracts (
    id bigint auto_increment primary key,
    reservation_id bigint not null unique,
    vehicle_id bigint not null,
    employee_id bigint not null,
    start_date date not null,
    expected_end_date date not null,
    actual_return_date date null,
    rental_value decimal(12,2) not null,
    status enum('ABIERTO', 'CERRADO') not null default 'ABIERTO',
    check (expected_end_date > start_date),
    check (actual_return_date is null or actual_return_date >= start_date),
    check (rental_value >= 0),
    foreign key (reservation_id) references reservations(id),
    foreign key (vehicle_id) references vehicles(id),
    foreign key (employee_id) references employees(id)
) auto_increment = 9001;

create table contract_drivers (
    id bigint auto_increment primary key,
    contract_id bigint not null,
    additional_driver_id bigint not null,
    unique (contract_id, additional_driver_id),
    foreign key (contract_id) references contracts(id),
    foreign key (additional_driver_id) references additional_drivers(id)
);

create table contract_extras (
    id bigint auto_increment primary key,
    contract_id bigint not null,
    extra_id bigint not null,
    quantity int not null default 1,
    agreed_price decimal(12,2) not null,
    unique (contract_id, extra_id),
    check (quantity >= 1),
    check (agreed_price > 0),
    foreign key (contract_id) references contracts(id),
    foreign key (extra_id) references extras(id)
);


-- 5. Entrega, devolución, inspección y daños


create table deliveries (
    id bigint auto_increment primary key,
    contract_id bigint not null unique,
    occurred_at datetime not null,
    mileage_km int not null,
    fuel_pct tinyint not null,
    branch_id bigint not null,
    employee_id bigint not null,
    check (mileage_km >= 0),
    check (fuel_pct between 0 and 100),
    foreign key (contract_id) references contracts(id),
    foreign key (branch_id) references branches(id),
    foreign key (employee_id) references employees(id)
);

create table vehicle_returns (
    id bigint auto_increment primary key,
    contract_id bigint not null unique,
    occurred_at datetime not null,
    mileage_km int not null,
    fuel_pct tinyint not null,
    branch_id bigint not null,
    employee_id bigint not null,
    check (mileage_km >= 0),
    check (fuel_pct between 0 and 100),
    foreign key (contract_id) references contracts(id),
    foreign key (branch_id) references branches(id),
    foreign key (employee_id) references employees(id)
);

create table inspections (
    id bigint auto_increment primary key,
    contract_id bigint not null,
    stage enum('ENTREGA', 'DEVOLUCION') not null,
    occurred_at datetime not null,
    exterior_ok boolean not null,
    interior_ok boolean not null,
    notes varchar(300) null,
    employee_id bigint not null,
    unique (contract_id, stage),
    foreign key (contract_id) references contracts(id),
    foreign key (employee_id) references employees(id)
);

create table damages (
    id bigint auto_increment primary key,
    inspection_id bigint not null,
    description varchar(200) not null,
    severity enum('LEVE', 'MODERADO', 'GRAVE') not null,
    repair_cost decimal(12,2) not null,
    charged_to_customer boolean not null default false,
    check (repair_cost >= 0),
    foreign key (inspection_id) references inspections(id)
);


-- 6. Dinero


create table deposits (
    id bigint auto_increment primary key,
    contract_id bigint not null unique,
    amount decimal(12,2) not null,
    retained_at datetime not null,
    released_at datetime null,
    applied_to_damages decimal(12,2) not null default 0,
    status enum('RETENIDO', 'LIBERADO', 'APLICADO') not null default 'RETENIDO',
    check (amount > 0),
    check (applied_to_damages >= 0),
    check (applied_to_damages <= amount),
    foreign key (contract_id) references contracts(id)
);

create table payments (
    id bigint auto_increment primary key,
    contract_id bigint not null,
    concept enum('ALQUILER', 'EXTRAS', 'DAÑOS', 'CIERRE') not null,
    amount decimal(12,2) not null,
    method enum('TARJETA', 'EFECTIVO', 'TRANSFERENCIA', 'DEPOSITO') not null,
    paid_at datetime not null,
    card_last4 char(4) null,
    authorization_code varchar(30) null,
    check (amount > 0),
    check (card_last4 is null or CHAR_LENGTH(card_last4) = 4),
    foreign key (contract_id) references contracts(id)
);

show TABLES;

DESCRIBE contracts;
DESCRIBE reservations;
