-- Funciones, procedimientos y controles de negocio | FlotaYa
-- Se mantienen los datos, reglas, orden de ejecución y salidas del taller.
-- Se reorganizaron los nombres internos y la presentación del SQL.

-- Taller 2 · FlotaYa · Fase 5 · DQL avanzado
-- Funciones, procedimientos, roles y cuentas. Se ejecuta después de
-- 03_dql.sql. El script se puede repetir dos veces seguidas.
use flotaya;

-- 5.1 FUNCIONES
-- fn_prueba_1418 · MySQL exige declarar características en funciones
-- ESPERADO: ERROR 1418 (HY000): This function has none of DETERMINISTIC,
-- NO SQL, or READS SQL DATA in its declaration and binary logging is enabled
--
-- DROP FUNCTION IF EXISTS fn_prueba_1418;
-- DELIMITER $$
-- CREATE FUNCTION fn_prueba_1418()
-- RETURNS INT
-- BEGIN
--    RETURN 1;
-- END $$
-- DELIMITER ;
--
-- MySQL pide declarar si la función es determinista y si lee datos porque,
-- con el binary log activo, necesita garantizar que la función dé el mismo
-- resultado en la réplica. Sin esa promesa, rechaza crearla (1418).

-- fn_edad_conductor · años cumplidos a una fecha de referencia
-- DETERMINISTIC + NO SQL: solo calcula con sus dos parámetros, no lee
-- tablas ni el reloj del servidor y siempre da el mismo resultado.
drop function if exists fn_edad_conductor;

delimiter $$

create function fn_edad_conductor(param_birth_date date, param_reference_date date)
returns int
DETERMINISTIC
NO SQL
begin
    return timestampdiff(year, param_birth_date, param_reference_date);
end $$

delimiter ;

select fn_edad_conductor('2004-07-15', '2026-07-14') as un_dia_antes,   -- 21
       fn_edad_conductor('2004-07-15', '2026-07-15') as el_cumple,      -- 22
       fn_edad_conductor('2004-07-15', '2026-11-23') as al_corte;       -- 22

-- fn_valor_alquiler · regla 8, noche por noche
-- READS SQL DATA + NOT DETERMINISTIC: consulta seasons y season_rates y su
-- resultado cambia si cambian las tarifas (por ejemplo, el alza de Lujo).
drop function if exists fn_valor_alquiler;

delimiter $$

create function fn_valor_alquiler(param_category_id bigint, param_pickup_date date, param_return_date date)
returns decimal(12,2)
READS SQL DATA
not DETERMINISTIC
begin
    declare local_day    date;
    declare local_rate   decimal(12,2);
    declare local_total  decimal(12,2) default 0;
    declare local_msg    varchar(255);

    if param_return_date <= param_pickup_date then
        signal sqlstate '45000'
            set message_text = 'La fecha final debe ser posterior a la inicial';
    end if;

    set local_day = param_pickup_date;

    while local_day < param_return_date do
        set local_rate = null;

        select ref_r.daily_rate into local_rate
        from seasons as ref_s
        join season_rates as ref_r on ref_r.season_type = ref_s.season_type
        where ref_r.category_id = param_category_id
          and local_day between ref_s.start_date and ref_s.end_date;

        if local_rate is null then
            set local_msg = concat('No hay temporada o tarifa para el día ',
                               date_format(local_day, '%Y-%m-%d'));
            signal sqlstate '45000' set message_text = local_msg;
        end if;

        set local_total = local_total + local_rate;
        set local_day = date_add(local_day, interval 1 day);
    end while;

    return local_total;
end $$

delimiter ;

-- Casos de prueba (todos deben coincidir con el enunciado)
select fn_valor_alquiler(1, '2026-11-27', '2026-12-02') as economico_diciembre,   -- 620000
       fn_valor_alquiler(5, '2026-12-18', '2026-12-23') as van_fin_de_ano,        -- 2300000
       fn_valor_alquiler(3, '2026-10-08', '2026-10-12') as suv_receso_octubre,    -- 1080000
       fn_valor_alquiler(6, '2026-12-14', '2026-12-16') as lujo_con_alza;         -- 1202500

-- ESPERADO: ERROR 1644 (45000): La fecha final debe ser posterior a la inicial
-- SELECT fn_valor_alquiler(1, '2026-12-05', '2026-12-05');

-- ESPERADO: ERROR 1644 (45000): No hay temporada o tarifa para el día 2027-01-16
-- SELECT fn_valor_alquiler(1, '2027-01-14', '2027-01-18');

-- fn_licencia_vigente · regla 11
-- READS SQL DATA + NOT DETERMINISTIC: lee driver_licenses y depende de la
-- fecha y de los datos del cliente.
drop function if exists fn_licencia_vigente;

delimiter $$

create function fn_licencia_vigente(param_customer_id bigint, param_reference_date date)
returns boolean
READS SQL DATA
not DETERMINISTIC
begin
    declare local_count int;

    select count(*) into local_count
    from driver_licenses as ref_dl
    where ref_dl.customer_id = param_customer_id
      and ref_dl.issue_date  <= param_reference_date
      and ref_dl.expiry_date >= param_reference_date;

    return local_count > 0;
end $$

delimiter ;

select fn_licencia_vigente(7,  '2026-11-23') as jorge_al_corte,        -- 1
       fn_licencia_vigente(8,  '2026-11-23') as paola_al_corte,        -- 1
       fn_licencia_vigente(8,  '2026-12-15') as paola_15_dic,          -- 0
       fn_licencia_vigente(9,  '2026-12-15') as esteban_15_dic,        -- 0
       fn_licencia_vigente(12, '2026-12-15') as laura_15_dic;          -- 0

-- Uso de las funciones en consultas
-- Clientes menores de 25 años al corte
select concat(ref_cu.first_name, ' ', ref_cu.last_name)                        as cliente,
       ref_cu.birth_date                                                   as nacimiento,
       fn_edad_conductor(ref_cu.birth_date, '2026-11-23')                   as edad,
       if(fn_edad_conductor(ref_cu.birth_date, '2026-11-23') >= 23, 'Sí', 'No') as puede_suv,
       if(fn_edad_conductor(ref_cu.birth_date, '2026-11-23') >= 25, 'Sí', 'No') as puede_4x4_o_van
from customers as ref_cu
where fn_edad_conductor(ref_cu.birth_date, '2026-11-23') < 25
order by edad asc, cliente;

-- Clientes que no podrían manejar el 2026-12-15
select ref_cu.id                                                            as id,
       concat(ref_cu.first_name, ' ', ref_cu.last_name)                         as cliente,
       if(fn_licencia_vigente(ref_cu.id, '2026-11-23'), 'Sí', 'No')          as vigente_al_corte,
       if(fn_licencia_vigente(ref_cu.id, '2026-12-15'), 'Sí', 'No')          as vigente_15_dic
from customers as ref_cu
where not fn_licencia_vigente(ref_cu.id, '2026-12-15')
order by ref_cu.id;

-- 5.2 PROCEDIMIENTOS
-- sp_crear_reserva · valida las reglas 14 y 15 en el orden pedido
drop procedure if exists sp_crear_reserva;

delimiter $$

create procedure sp_crear_reserva(
    in  param_customer_id      bigint,
    in  param_vehicle_id       bigint,
    in  param_pickup_branch_id bigint,
    in  param_return_branch_id bigint,
    in  param_pickup_date      date,
    in  param_return_date      date,
    out param_reservation_number bigint
)
begin
    declare local_count        int;
    declare local_customer_status varchar(20);
    declare local_vehicle_status  varchar(20);
    declare local_category_id  bigint;
    declare local_min_age      int;
    declare local_age          int;
    declare local_birth_date   date;
    declare local_quoted       decimal(12,2);
    declare local_msg          varchar(255);

    -- 1. El cliente existe
    select count(*) into local_count from customers where id = param_customer_id;
    if local_count = 0 then
        signal sqlstate '45000' set message_text = 'El cliente no existe';
    end if;

    -- 2. El cliente no está bloqueado
    select status into local_customer_status from customers where id = param_customer_id;
    if local_customer_status = 'BLOQUEADO' then
        signal sqlstate '45000' set message_text = 'El cliente está bloqueado';
    end if;

    -- 3. La devolución es posterior a la recogida
    if param_return_date <= param_pickup_date then
        signal sqlstate '45000' set message_text = 'La devolución debe ser posterior a la recogida';
    end if;

    -- 4. El vehículo existe
    select count(*) into local_count from vehicles where id = param_vehicle_id;
    if local_count = 0 then
        signal sqlstate '45000' set message_text = 'El vehículo no existe';
    end if;

    -- 5. El vehículo no está fuera de servicio
    select status into local_vehicle_status from vehicles where id = param_vehicle_id;
    if local_vehicle_status = 'FUERA_DE_SERVICIO' then
        signal sqlstate '45000' set message_text = 'El vehículo está fuera de servicio';
    end if;

    -- 6. Ninguna reserva viva del vehículo comparte un día (regla 14)
    select count(*) into local_count
    from reservations as ref_r
    where ref_r.vehicle_id = param_vehicle_id
      and ref_r.status in ('PENDIENTE', 'CONFIRMADA', 'CONVERTIDA')
      and ref_r.pickup_date <= param_return_date
      and ref_r.return_date >= param_pickup_date;

    if local_count > 0 then
        signal sqlstate '45000' set message_text = 'El vehículo ya está reservado en esas fechas';
    end if;

    -- 7. Edad mínima de la categoría el día de la recogida
    select ref_m.category_id, ref_c.min_age
      into local_category_id, local_min_age
    from vehicles as ref_v
    join models as ref_m     on ref_m.id = ref_v.model_id
    join categories as ref_c on ref_c.id = ref_m.category_id
    where ref_v.id = param_vehicle_id;

    select birth_date into local_birth_date from customers where id = param_customer_id;
    set local_age = fn_edad_conductor(local_birth_date, param_pickup_date);

    if local_age < local_min_age then
        set local_msg = concat('El cliente tiene ', local_age,
                           ' años y la categoría exige ', local_min_age);
        signal sqlstate '45000' set message_text = local_msg;
    end if;

    -- 8. Licencia vigente hasta el día de la devolución
    if not fn_licencia_vigente(param_customer_id, param_return_date) then
        signal sqlstate '45000'
            set message_text = 'El cliente no tiene licencia vigente durante todo el alquiler';
    end if;

    -- Hace: registra la reserva PENDIENTE con el valor calculado
    set local_quoted = fn_valor_alquiler(local_category_id, param_pickup_date, param_return_date);

    insert into reservations (customer_id, vehicle_id, pickup_branch_id, return_branch_id,
                              pickup_date, return_date, quoted_value, created_at, status)
    values (param_customer_id, param_vehicle_id, param_pickup_branch_id, param_return_branch_id,
            param_pickup_date, param_return_date, local_quoted, '2026-11-23 08:00:00', 'PENDIENTE');

    set param_reservation_number = last_insert_id();
end $$

delimiter ;

-- Prueba 1 · Jorge Arango, Hilux HLX701, El Poblado -> El Poblado, 12-19 a 12-22
call sp_crear_reserva(7, 14, 3, 3, '2026-12-19', '2026-12-22', @revision_num_reserva);
select @revision_num_reserva as reserva_creada;

select id, customer_id, vehicle_id, pickup_date, return_date, quoted_value, status
from reservations where id = @revision_num_reserva;
-- Esperado: reserva PENDIENTE cotizada en 1290000.00 (3 noches ALTA de 4x4)

-- ESPERADO: ERROR 1644 (45000): El vehículo ya está reservado en esas fechas
-- (prueba 2: cruce con la reserva 501 de Juliana Patiño)
-- CALL sp_crear_reserva(2, 1, 1, 1, '2026-11-30', '2026-12-04', @revision_num_x);

-- ESPERADO: ERROR 1644 (45000): El cliente tiene 22 años y la categoría exige 23
-- (prueba 3: Juliana Patiño en una SUV)
-- CALL sp_crear_reserva(3, 13, 4, 4, '2026-12-12', '2026-12-14', @revision_num_x);

-- ESPERADO: ERROR 1644 (45000): El cliente no tiene licencia vigente durante todo el alquiler
-- (prueba 4: la licencia de Paola Quintero vence el 2026-12-10)
-- CALL sp_crear_reserva(8, 2, 2, 2, '2026-12-08', '2026-12-12', @revision_num_x);

-- ESPERADO: ERROR 1644 (45000): El cliente está bloqueado
-- (prueba 5: Martha Cifuentes)
-- CALL sp_crear_reserva(10, 2, 2, 2, '2026-12-01', '2026-12-03', @revision_num_x);

-- ESPERADO: ERROR 1644 (45000): El vehículo está fuera de servicio
-- (prueba 6: KWD103)
-- CALL sp_crear_reserva(1, 3, 6, 6, '2026-12-01', '2026-12-03', @revision_num_x);

-- sp_cerrar_contrato · regla 23 completa, sin COMMIT propio
drop procedure if exists sp_cerrar_contrato;

delimiter $$

create procedure sp_cerrar_contrato(
    in  param_contract_id bigint,
    in  param_close_date  date,
    out param_balance     decimal(12,2)
)
begin
    declare local_count           int;
    declare local_status          varchar(20);
    declare local_start_date      date;
    declare local_vehicle_id      bigint;
    declare local_category_id     bigint;
    declare local_real_return     date;
    declare local_return_branch   bigint;
    declare local_return_mileage  int;
    declare local_nights          int;
    declare local_rental          decimal(12,2);
    declare local_extras          decimal(12,2);
    declare local_damages         decimal(12,2);
    declare local_paid            decimal(12,2);
    declare local_deposit         decimal(12,2);
    declare local_applied         decimal(12,2);

    -- 1. El contrato existe
    select count(*) into local_count from contracts where id = param_contract_id;
    if local_count = 0 then
        signal sqlstate '45000' set message_text = 'El contrato no existe';
    end if;

    -- 2. Está ABIERTO
    select status into local_status from contracts where id = param_contract_id;
    if local_status <> 'ABIERTO' then
        signal sqlstate '45000' set message_text = 'El contrato no está abierto';
    end if;

    -- 3. Tiene la devolución registrada
    select count(*) into local_count from vehicle_returns where contract_id = param_contract_id;
    if local_count = 0 then
        signal sqlstate '45000' set message_text = 'El contrato no tiene devolución registrada';
    end if;

    -- 4. Tiene la inspección de devolución
    select count(*) into local_count
    from inspections
    where contract_id = param_contract_id and stage = 'DEVOLUCION';
    if local_count = 0 then
        signal sqlstate '45000' set message_text = 'Falta la inspección de devolución';
    end if;

    -- 5. La fecha de cierre es posterior al inicio
    select start_date into local_start_date from contracts where id = param_contract_id;
    if param_close_date <= local_start_date then
        signal sqlstate '45000' set message_text = 'La fecha de cierre debe ser posterior al inicio';
    end if;

    -- Datos de devolución y del vehículo
    select vehicle_id into local_vehicle_id from contracts where id = param_contract_id;
    select ref_m.category_id
      into local_category_id
    from vehicles as ref_v
    join models as ref_m on ref_m.id = ref_v.model_id
    where ref_v.id = local_vehicle_id;

    select date(occurred_at), branch_id, mileage_km
      into local_real_return, local_return_branch, local_return_mileage
    from vehicle_returns
    where contract_id = param_contract_id;

    set local_nights = datediff(local_real_return, local_start_date);

    -- Regla 23: alquiler recalculado con la fecha real, extras y daños
    set local_rental = fn_valor_alquiler(local_category_id, local_start_date, local_real_return);

    select coalesce(sum(quantity * agreed_price), 0) into local_extras
    from contract_extras where contract_id = param_contract_id;

    set local_extras = local_extras * local_nights;

    select coalesce(sum(ref_d.repair_cost), 0) into local_damages
    from damages as ref_d
    join inspections as ref_i on ref_i.id = ref_d.inspection_id
    where ref_i.contract_id = param_contract_id
      and ref_i.stage = 'DEVOLUCION'
      and ref_d.charged_to_customer = true;

    select coalesce(sum(amount), 0) into local_paid
    from payments where contract_id = param_contract_id;

    select amount into local_deposit from deposits where contract_id = param_contract_id;

    -- El depósito se aplica a los daños o se libera
    if local_damages > 0 then
        set local_applied = LEAST(local_deposit, local_damages);

        update deposits
        set applied_to_damages = local_applied,
            released_at        = param_close_date,
            status             = 'APLICADO'
        where contract_id = param_contract_id;

        if local_applied > 0 then
            insert into payments (contract_id, concept, amount, method, paid_at)
            values (param_contract_id, 'DAÑOS', local_applied, 'DEPOSITO', param_close_date);
        end if;
    else
        set local_applied = 0;

        update deposits
        set applied_to_damages = 0,
            released_at        = param_close_date,
            status             = 'LIBERADO'
        where contract_id = param_contract_id;
    end if;

    -- Contrato cerrado y vehículo disponible en la sede de devolución
    update contracts
    set rental_value       = local_rental,
        actual_return_date = local_real_return,
        status             = 'CERRADO'
    where id = param_contract_id;

    update vehicles
    set status     = 'DISPONIBLE',
        mileage_km = local_return_mileage,
        branch_id  = local_return_branch
    where id = local_vehicle_id;

    set param_balance = local_rental + local_extras + local_damages - local_paid - local_applied;
end $$

delimiter ;

-- ESPERADO: ERROR 1644 (45000): El contrato no está abierto
-- (prueba 1: el contrato 9001 ya está cerrado)
-- CALL sp_cerrar_contrato(9001, '2026-10-06', @revision_saldo_x);

-- ESPERADO: ERROR 1644 (45000): El contrato no tiene devolución registrada
-- (prueba 2: Carlos Mejía todavía tiene el carro)
-- CALL sp_cerrar_contrato(9007, '2026-11-23', @revision_saldo_x);

-- Prueba 3 · Devolución y cierre del Onix de Ricardo Lozano (contrato 9006)
insert into vehicle_returns (contract_id, occurred_at, mileage_km, fuel_pct, branch_id, employee_id)
values (9006, '2026-11-21 10:00:00', 30910, 100, 1, 3);

insert into inspections (contract_id, stage, occurred_at, exterior_ok, interior_ok, notes, employee_id)
values (9006, 'DEVOLUCION', '2026-11-21 10:10:00', true, true, null, 3);

call sp_cerrar_contrato(9006, '2026-11-21', @revision_saldo_ricardo);
commit;

select @revision_saldo_ricardo as saldo_ricardo;   -- Esperado: 60000.00

select ref_ct.id, ref_ct.status, ref_ct.rental_value, ref_ct.actual_return_date,
       ref_v.plate, ref_v.status as estado_vehiculo, ref_v.mileage_km, ref_b.name as sede,
       ref_d.status as estado_deposito
from contracts as ref_ct
join vehicles as ref_v  on ref_v.id = ref_ct.vehicle_id
join branches as ref_b  on ref_b.id = ref_v.branch_id
join deposits as ref_d  on ref_d.contract_id = ref_ct.id
where ref_ct.id = 9006;
-- Esperado: CERRADO · 600000.00 · 2026-11-21 · ONX301 DISPONIBLE en Calle 26
-- con 30910 km y depósito LIBERADO

-- 5.3 USUARIOS, ROLES Y PRIVILEGIOS (regla 24)
-- Se puede repetir: borrar la base no borra cuentas ni roles, así que el
-- script las elimina antes de crearlas.
drop user if exists 'asesor_flotaya'@'localhost';
drop user if exists 'taller_flotaya'@'localhost';
drop user if exists 'auditor_flotaya'@'localhost';

drop role if exists rol_asesor_flotaya;
drop role if exists rol_taller_flotaya;
drop role if exists rol_auditor_flotaya;

create role rol_asesor_flotaya;
create role rol_taller_flotaya;
create role rol_auditor_flotaya;

-- ---- Asesor de mostrador: reservas, clientes, vehículos y cotización ----
grant select on flotaya.reservations to rol_asesor_flotaya;
grant update (status) on flotaya.reservations to rol_asesor_flotaya;
grant select on flotaya.customers to rol_asesor_flotaya;
grant select on flotaya.vehicles to rol_asesor_flotaya;
grant EXECUTE on procedure flotaya.sp_crear_reserva to rol_asesor_flotaya;
grant EXECUTE on function flotaya.fn_valor_alquiler to rol_asesor_flotaya;

-- ---- Taller: mantenimientos completos y del vehículo solo lo mínimo ----
grant select, insert, update on flotaya.maintenances to rol_taller_flotaya;
grant select (id, plate, status, mileage_km, branch_id) on flotaya.vehicles to rol_taller_flotaya;
grant update (status) on flotaya.vehicles to rol_taller_flotaya;

-- ---- Auditor externo: lectura amplia, pagos sin datos sensibles ----
grant select on flotaya.contracts to rol_auditor_flotaya;
grant select on flotaya.reservations to rol_auditor_flotaya;
grant select on flotaya.vehicles to rol_auditor_flotaya;
grant select on flotaya.maintenances to rol_auditor_flotaya;
grant select on flotaya.vehicle_returns to rol_auditor_flotaya;
grant select on flotaya.inspections to rol_auditor_flotaya;
grant select on flotaya.damages to rol_auditor_flotaya;
grant select on flotaya.deposits to rol_auditor_flotaya;
grant select (id, contract_id, concept, amount, paid_at) on flotaya.payments to rol_auditor_flotaya;

-- ---- Cuentas con su rol activo al conectarse ----
create user 'asesor_flotaya'@'localhost'  identified by 'Practica_2026*';
create user 'taller_flotaya'@'localhost'  identified by 'Practica_2026*';
create user 'auditor_flotaya'@'localhost' identified by 'Practica_2026*';

grant rol_asesor_flotaya  to 'asesor_flotaya'@'localhost';
grant rol_taller_flotaya  to 'taller_flotaya'@'localhost';
grant rol_auditor_flotaya to 'auditor_flotaya'@'localhost';

set default role all to 'asesor_flotaya'@'localhost';
set default role all to 'taller_flotaya'@'localhost';
set default role all to 'auditor_flotaya'@'localhost';

-- Revisión de privilegios del rol del taller
show GRANTS for rol_taller_flotaya;

-- PRUEBAS DE ACCESO (una conexión de Workbench por cuenta: 127.0.0.1,
-- usuario y clave Practica_2026*). Se dejan aquí como guía comentada.
--
-- -- Como asesor_flotaya -------------------------------------------------
-- SELECT CURRENT_USER() AS usuario, CURRENT_ROLE() AS rol_activo;
-- SHOW TABLES;
--
-- -- Permitido: crear con el procedimiento y confirmar
-- CALL sp_crear_reserva(14, 13, 4, 4, '2026-12-12', '2026-12-15', @revision_nueva);
-- SELECT @revision_nueva AS reserva;
-- UPDATE reservations SET status = 'CONFIRMADA' WHERE id = @revision_nueva;
--
-- -- Cotizar
-- SELECT fn_valor_alquiler(3, '2026-12-12', '2026-12-15') AS cotizacion;
--
-- -- ESPERADO: ERROR 1142 · SELECT sobre pagos no permitido
-- SELECT * FROM payments;
-- -- ESPERADO: ERROR 1142 · borrar reservas no permitido
-- DELETE FROM reservations WHERE id = @revision_nueva;
-- -- ESPERADO: ERROR 1142 · licencias no visibles
-- SELECT COUNT(*) FROM driver_licenses;
--
-- -- Sin el rol activo, la cuenta ve menos todavía:
-- SET ROLE NONE;
-- SHOW TABLES;
-- SET ROLE ALL;
--
-- -- Como taller_flotaya --------------------------------------------------
-- SELECT CURRENT_USER() AS usuario, CURRENT_ROLE() AS rol_activo;
--
-- -- Permitido: cerrar el cambio de embrague de la HLX702
-- UPDATE maintenances
-- SET end_date = '2026-11-23', cost = 1850000
-- WHERE id = 1;
-- UPDATE vehicles SET status = 'DISPONIBLE' WHERE id = 15;
--
-- -- Permitido: registrar un mantenimiento preventivo de la SPT602
-- INSERT INTO maintenances (vehicle_id, maintenance_type, description, workshop, start_date, end_date, cost)
-- VALUES (13, 'PREVENTIVO', 'Alineación y balanceo', 'Taller FlotaYa Bogotá', '2026-11-23', '2026-11-23', 120000);
--
-- -- ESPERADO: ERROR 1142 · no puede ver todos los datos del vehículo
-- SELECT * FROM vehicles;
-- -- ESPERADO: ERROR 1143 · no puede cambiar el kilometraje
-- UPDATE vehicles SET mileage_km = 90000 WHERE id = 15;
-- -- ESPERADO: ERROR 1142 · no ve contratos
-- SELECT COUNT(*) FROM contracts;
--
-- -- Como auditor_flotaya ------------------------------------------------
-- SELECT CURRENT_USER() AS usuario, CURRENT_ROLE() AS rol_activo;
--
-- -- Permitido: pagos del contrato de Emma Walker sin el medio de pago
-- SELECT id, contract_id, concept, amount, paid_at
-- FROM payments WHERE contract_id = 9003;
--
-- -- Permitido: contar contratos por estado
-- SELECT status, COUNT(*) FROM contracts GROUP BY status;
--
-- -- ESPERADO: ERROR 1143 · no ve los últimos 4 dígitos de la tarjeta
-- SELECT card_last4 FROM payments;
-- -- ESPERADO: ERROR 1142 · no ve todos los datos de los pagos
-- SELECT * FROM payments;
-- -- ESPERADO: ERROR 1142 · no modifica datos
-- UPDATE contracts SET status = 'ABIERTO' WHERE id = 9001;
-- -- ESPERADO: ERROR 1142 · no ve clientes
-- SELECT COUNT(*) FROM customers;
--
-- RESPUESTAS
-- 1. El asesor creó una reserva que valida licencias sin poder leerlas
--   porque el procedimiento es SQL SECURITY DEFINER: se ejecuta con los
--   privilegios de quien lo creó (root), no con los del asesor. El asesor
--   solo tiene EXECUTE. El riesgo es la escalada de privilegios: si el
--   procedimiento devolviera datos de las licencias o aceptara SQL libre,
--   el asesor vería a través de él lo que la matriz le prohíbe. Por eso el
--   procedimiento solo valida y no muestra nada de licencias.
--
-- 2. El 1142 niega el privilegio sobre la TABLA: `SELECT *` pide todas las
--   columnas y MySQL lo resuelve como un permiso de tabla, así que la cuenta
--   que solo tiene privilegios por columna no puede usarlo. El 1143 niega
--   una COLUMNA concreta: el auditor puede leer id, contract_id, concept,
--   amount y paid_at de payments, pero al pedir card_last4 tropieza con la
--   columna prohibida. Por eso el mismo tipo de consulta da códigos distintos.
--
-- 3. Si la cuenta tiene el rol asignado pero no activo (sin DEFAULT ROLE o
--   tras SET ROLE NONE), la sesión arranca solo con USAGE: puede conectarse,
--   pero cualquier consulta falla con 1142/1143 como si no tuviera permisos.
--   Los roles se activan por sesión; por eso el script usa SET DEFAULT ROLE.