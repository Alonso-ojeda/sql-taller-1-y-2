-- Pruebas transaccionales, confirmación y reversión | FlotaYa
-- Se mantienen los datos, reglas, orden de ejecución y salidas del taller.
-- Se reorganizaron los nombres internos y la presentación del SQL.

-- 05_tcl.sql
use flotaya;


-- 6.1 · Cierre del contrato de Paola Quintero (con SAVEPOINT)

start transaction;

-- Estado inicial
select ref_ct.id             as contrato,
       ref_ct.status         as estado,
       ref_ct.rental_value   as alquiler,
       ref_v.plate           as placa,
       ref_v.status          as estado_vehiculo,
       ref_d.status          as estado_deposito,
       (select coalesce(sum(amount), 0) from payments where contract_id = 9005) as pagado
from contracts as ref_ct
join vehicles as ref_v on ref_v.id = ref_ct.vehicle_id
join deposits as ref_d on ref_d.contract_id = ref_ct.id
where ref_ct.id = 9005;

-- 1. Devolución: 09:30, 12.480 km, tanque lleno, la recibe Carolina Zapata
insert into vehicle_returns (contract_id, occurred_at, mileage_km, fuel_pct, branch_id, employee_id)
values (9005, '2026-11-23 09:30:00', 12480, 100, 2, 9);

-- Inspección de devolución: 09:40, exterior con novedad
insert into inspections (contract_id, stage, occurred_at, exterior_ok, interior_ok, notes, employee_id)
values (9005, 'DEVOLUCION', '2026-11-23 09:40:00', false, true,
        'Rin delantero izquierdo rayado', 9);

-- 2. Guardar el número de la inspección ANTES de seguir
set @revision_local_inspeccion_paola = last_insert_id();
select @revision_local_inspeccion_paola as inspeccion_devolucion;

-- 3. Punto de guardado
savepoint antes_dano;

-- 4. Daño registrado por error en 3.800.000
insert into damages (inspection_id, description, severity, repair_cost, charged_to_customer)
values (@revision_local_inspeccion_paola, 'Rin delantero izquierdo rayado', 'LEVE', 3800000, true);

select id, description, severity, repair_cost
from damages where inspection_id = @revision_local_inspeccion_paola;

-- 5. Deshacer SOLO ese error y registrar el daño correcto (380.000)
rollback to savepoint antes_dano;

insert into damages (inspection_id, description, severity, repair_cost, charged_to_customer)
values (@revision_local_inspeccion_paola, 'Rin delantero izquierdo rayado', 'LEVE', 380000, true);

select id, description, severity, repair_cost
from damages where inspection_id = @revision_local_inspeccion_paola;

-- 6. Cerrar el contrato
call sp_cerrar_contrato(9005, '2026-11-23', @revision_saldo_paola);
select @revision_saldo_paola as saldo_del_cierre;   -- Esperado: 750000.00

-- 7. Cobrar el saldo con tarjeta y confirmar
insert into payments (contract_id, concept, amount, method, paid_at, card_last4, authorization_code)
values (9005, 'CIERRE', @revision_saldo_paola, 'TARJETA', '2026-11-23 10:00:00', '3307', 'AUT-580114');

-- Estado final
select ref_ct.id           as contrato,
       ref_ct.status       as estado,
       ref_ct.rental_value as alquiler,
       ref_v.plate         as placa,
       ref_v.status        as estado_vehiculo,
       ref_v.mileage_km    as kilometraje,
       ref_b.name          as sede,
       ref_d.status        as estado_deposito,
       ref_d.applied_to_damages as aplicado_a_danos,
       (select coalesce(sum(amount), 0) from payments where contract_id = 9005) as pagado,
       (select count(*) from damages where inspection_id = @revision_local_inspeccion_paola) as danos_en_la_inspeccion,
       (select group_concat(concept order by id) from payments where contract_id = 9005) as conceptos
from contracts as ref_ct
join vehicles as ref_v on ref_v.id = ref_ct.vehicle_id
join branches as ref_b on ref_b.id = ref_v.branch_id
join deposits as ref_d on ref_d.contract_id = ref_ct.id
where ref_ct.id = 9005;

commit;

-- Pregunta: ¿qué habría pasado si el segundo daño se registraba con el
-- último id generado (LAST_INSERT_ID()) en lugar de la variable del paso 2?
-- Respuesta: LAST_INSERT_ID() ya apuntaría al id del daño equivocado, así
-- que el daño "bueno" habría quedado colgado del daño (inspection_id
-- inexistente) y la inspección de Paola se habría quedado con el daño de
-- 3.800.000, o el INSERT habría fallado por la FK. La variable guardada
-- antes del savepoint es la que sobrevive al ROLLBACK.


-- 6.2 · Un cierre que debe deshacerse completo (Carlos Mejía)


start transaction;

-- Estado inicial
select ref_ct.id as contrato, ref_ct.status as estado, ref_ct.rental_value as alquiler,
       ref_v.plate as placa, ref_v.status as estado_vehiculo, ref_d.status as estado_deposito
from contracts as ref_ct
join vehicles as ref_v on ref_v.id = ref_ct.vehicle_id
join deposits as ref_d on ref_d.contract_id = ref_ct.id
where ref_ct.id = 9007;

-- Devolución en el Aeropuerto JMC: 18:00, 26.950 km, tanque a la mitad
insert into vehicle_returns (contract_id, occurred_at, mileage_km, fuel_pct, branch_id, employee_id)
values (9007, '2026-11-23 18:00:00', 26950, 50, 4, 10);

insert into inspections (contract_id, stage, occurred_at, exterior_ok, interior_ok, notes, employee_id)
values (9007, 'DEVOLUCION', '2026-11-23 18:10:00', true, true, null, 10);

call sp_cerrar_contrato(9007, '2026-11-23', @revision_saldo_carlos);
select @revision_saldo_carlos as saldo_carlos;   -- Esperado: 970000.00

-- Dentro de la transacción: contrato CERRADO y vehículo DISPONIBLE
select ref_ct.id as contrato, ref_ct.status as estado,
       ref_v.plate as placa, ref_v.status as estado_vehiculo, ref_d.status as estado_deposito
from contracts as ref_ct
join vehicles as ref_v on ref_v.id = ref_ct.vehicle_id
join deposits as ref_d on ref_d.contract_id = ref_ct.id
where ref_ct.id = 9007;

-- ESPERADO: ERROR 1265 (01000): Data truncated for column 'method' at row 1
-- El asesor intenta cobrar el saldo con CHEQUE (FlotaYa no recibe cheques).
-- Ejecutar sola, con la transacción abierta:
-- INSERT INTO payments (contract_id, concept, amount, method, paid_at)
-- VALUES (9007, 'CIERRE', @revision_saldo_carlos, 'CHEQUE', '2026-11-23 18:20:00');

-- El error no deshace la transacción: el asesor decide deshacerla completa
rollback;

-- Después del ROLLBACK: ABIERTO, ALQUILADO, RETENIDO, sin devolución
select ref_ct.id as contrato, ref_ct.status as estado,
       ref_v.plate as placa, ref_v.status as estado_vehiculo, ref_d.status as estado_deposito,
       (select count(*) from vehicle_returns where contract_id = 9007) as devoluciones,
       (select count(*) from inspections where contract_id = 9007 and stage = 'DEVOLUCION') as inspecciones_devolucion
from contracts as ref_ct
join vehicles as ref_v on ref_v.id = ref_ct.vehicle_id
join deposits as ref_d on ref_d.contract_id = ref_ct.id
where ref_ct.id = 9007;


-- 6.3 · Auditoría de consistencia (regla 23)


select
    (select count(*)
       from vehicles as ref_v
      where ref_v.status = 'ALQUILADO'
        and not exists (select 1 from contracts as ref_ct
                         where ref_ct.vehicle_id = ref_v.id and ref_ct.status = 'ABIERTO')
    ) as alquilados_sin_contrato,

    (select count(*)
       from contracts as ref_ct
      where ref_ct.status = 'CERRADO'
        and not exists (select 1 from vehicle_returns as ref_vr
                         where ref_vr.contract_id = ref_ct.id)
    ) as cerrados_sin_devolucion,

    (select count(*)
       from deposits as ref_d
       join contracts as ref_ct on ref_ct.id = ref_d.contract_id
      where ref_d.status = 'RETENIDO' and ref_ct.status = 'CERRADO'
    ) as depositos_retenidos_de_cerrados,

    (select count(*) from contracts where status = 'ABIERTO') as contratos_abiertos,

    (select count(*) from payments) as pagos;
-- Esperado: 0 · 0 · 0 · 1 (el contrato de Carlos Mejía, que volvió atrás) · 14