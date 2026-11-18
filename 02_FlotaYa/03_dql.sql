-- Consultas para los casos solicitados | FlotaYa
-- Se mantienen los datos, reglas, orden de ejecución y salidas del taller.
-- Se reorganizaron los nombres internos y la presentación del SQL.

-- Taller 2 · FlotaYa · Fase 4 · DQL
-- Se ejecuta después de 02_dml.sql completo (incluidas las operaciones
-- del día). Fecha de corte fija: 2026-11-23. Nunca NOW() ni CURDATE().
use flotaya;

-- Consulta Q-01 · ¿Cómo está repartida la flota hoy?
select ref_v.status          as estado,
       count(*)          as vehiculos
from vehicles as ref_v
group by ref_v.status
order by vehiculos desc, estado asc;
-- Esperado: DISPONIBLE 12 · ALQUILADO 3 · MANTENIMIENTO 2 · FUERA_DE_SERVICIO 1

-- Consulta Q-02 · ¿Cuánto duran las temporadas altas?
select ref_s.name                                        as temporada,
       ref_s.start_date                                  as desde,
       ref_s.end_date                                    as hasta,
       datediff(ref_s.end_date, ref_s.start_date) + 1        as dias
from seasons as ref_s
where ref_s.season_type = 'ALTA'
order by ref_s.start_date;

-- Consulta Q-03 · ¿Qué carros podemos ofrecer ya mismo?
select ref_v.plate      as placa,
       ref_b.name       as marca,
       ref_m.name       as modelo,
       ref_c.name       as categoria,
       ref_br.name      as sede,
       ref_ci.name      as ciudad
from vehicles as ref_v
join models as ref_m     on ref_m.id = ref_v.model_id
join brands as ref_b     on ref_b.id = ref_m.brand_id
join categories as ref_c on ref_c.id = ref_m.category_id
join branches as ref_br  on ref_br.id = ref_v.branch_id
join cities as ref_ci    on ref_ci.id = ref_br.city_id
where ref_v.status = 'DISPONIBLE'
order by field(ref_c.name, 'Económico', 'Compacto', 'SUV', 'Camioneta 4x4', 'Van', 'Lujo'),
         ref_v.plate;

-- Consulta Q-04 · ¿Qué contratos abiertos están atrasados o por vencer?
select ref_ct.id                                       as contrato,
       concat(ref_cu.first_name, ' ', ref_cu.last_name)    as cliente,
       ref_v.plate                                     as placa,
       ref_m.name                                      as modelo,
       ref_br.name                                     as sede_recogida,
       ref_ct.expected_end_date                        as fin_esperado,
       datediff(ref_ct.expected_end_date, '2026-11-23') as dias_para_devolver,
       count(ref_cd.additional_driver_id)              as conductores_adicionales
from contracts as ref_ct
join reservations as ref_r on ref_r.id = ref_ct.reservation_id
join customers as ref_cu   on ref_cu.id = ref_r.customer_id
join vehicles as ref_v     on ref_v.id = ref_ct.vehicle_id
join models as ref_m       on ref_m.id = ref_v.model_id
join branches as ref_br    on ref_br.id = ref_r.pickup_branch_id
left join contract_drivers as ref_cd on ref_cd.contract_id = ref_ct.id
where ref_ct.status = 'ABIERTO'
group by ref_ct.id, cliente, ref_v.plate, ref_m.name, ref_br.name, ref_ct.expected_end_date
order by dias_para_devolver asc, ref_ct.id;

-- Consulta Q-05 · ¿Qué sedes recaudan más?
select ref_br.name                        as sede,
       count(distinct ref_p.contract_id)  as contratos,
       round(sum(ref_p.amount), 2)        as recaudado
from payments as ref_p
join contracts as ref_ct     on ref_ct.id = ref_p.contract_id
join reservations as ref_r   on ref_r.id = ref_ct.reservation_id
join branches as ref_br      on ref_br.id = ref_r.pickup_branch_id
group by ref_br.id, ref_br.name
having sum(ref_p.amount) > 2000000
order by recaudado desc, sede;

-- Consulta Q-06 · ¿Qué modelos tenemos en el catálogo sin un solo carro?
select ref_b.name as marca,
       ref_m.name as modelo
from models as ref_m
join brands as ref_b on ref_b.id = ref_m.brand_id
where not exists (
    select 1 from vehicles ref_v
    where ref_v.model_id = ref_m.id
)
order by marca, modelo;


-- Consulta Q-07 · ¿Qué clientes no podrían manejar hoy?
select ref_cu.id                                     as id,
       concat(ref_cu.first_name, ' ', ref_cu.last_name)  as cliente
from customers as ref_cu
where not exists (
        select 1
        from driver_licenses as ref_dl
        where ref_dl.customer_id = ref_cu.id
          and ref_dl.issue_date  <= '2026-11-23'
          and ref_dl.expiry_date >= '2026-11-23'
      )
order by ref_cu.id;

-- Consulta Q-08 · ¿Qué carros siguen libres para diciembre?
select ref_v.plate  as placa,
       ref_m.name   as modelo,
       ref_br.name  as sede
from vehicles as ref_v
join models as ref_m    on ref_m.id = ref_v.model_id
join branches as ref_br on ref_br.id = ref_v.branch_id
where ref_v.status = 'DISPONIBLE'
  and not exists (
        select 1
        from reservations as ref_r
        where ref_r.vehicle_id = ref_v.id
          and ref_r.status in ('PENDIENTE', 'CONFIRMADA', 'CONVERTIDA')
          and ref_r.pickup_date <= '2026-12-31'
          and ref_r.return_date >= '2026-12-01'
      )
order by ref_v.plate;


-- Consulta Q-09 · ¿Qué vehículos nos están costando más en el taller?
with gastos as (
    select ref_v.id            as vehiculo_id,
           ref_v.plate         as placa,
           sum(ref_mt.cost)    as gasto
    from vehicles as ref_v
    join maintenances as ref_mt on ref_mt.vehicle_id = ref_v.id
    group by ref_v.id, ref_v.plate
)
select placa            as placa,
       round(gasto, 2)  as gasto
from gastos
where gasto > (select avg(gasto) from gastos)
order by gasto desc;

-- Segunda consulta: el promedio con el que se comparó
with gastos as (
    select ref_v.id         as vehiculo_id,
           ref_v.plate      as placa,
           sum(ref_mt.cost) as gasto
    from vehicles as ref_v
    join maintenances as ref_mt on ref_mt.vehicle_id = ref_v.id
    group by ref_v.id, ref_v.plate
)
select round(avg(gasto), 2) as promedio_por_vehiculo,
       count(*)             as vehiculos,
       count(gasto)         as con_gasto
from gastos;
-- Los mantenimientos en curso NO afectan el promedio: su costo es NULL y
-- SUM() lo ignora, así que ese vehículo queda con gasto NULL y AVG() lo
-- excluye. Cuenta como vehículo que entró al taller (6), pero no como
-- vehículo con gasto conocido (4). El promedio es 3.310.000 / 4 = 827.500.

-- Consulta Q-10 · ¿Cuál es el carro más rodado de cada categoría?
with ranking as (
    select ref_c.name           as categoria,
           ref_v.plate          as placa,
           ref_v.mileage_km     as kilometraje,
           row_number() over (partition by ref_c.id order by ref_v.mileage_km desc, ref_v.plate) as rn
    from vehicles as ref_v
    join models as ref_m     on ref_m.id = ref_v.model_id
    join categories as ref_c on ref_c.id = ref_m.category_id
)
select categoria, placa, kilometraje
from ranking
where rn = 1
order by field(categoria, 'Económico', 'Compacto', 'SUV', 'Camioneta 4x4', 'Van', 'Lujo');
-- Lujo no aparece porque no tiene ningún modelo y, por tanto, ningún vehículo.

-- Consulta Q-11 · ¿Cuánto dejan los extras?
select ref_e.name as extra,
       count(ref_ce.contract_id) as contratos,
       round(coalesce(sum(ref_ce.quantity * ref_ce.agreed_price *
             datediff(coalesce(ref_ct.actual_return_date, ref_ct.expected_end_date), ref_ct.start_date)), 0), 2) as ingresos
from extras as ref_e
left join contract_extras as ref_ce on ref_ce.extra_id = ref_e.id
left join contracts as ref_ct       on ref_ct.id = ref_ce.contract_id
group by ref_e.id, ref_e.name
order by ingresos desc, extra;

-- Consulta Q-12 · ¿Qué daños hemos encontrado?
select ref_ct.id                                     as contrato,
       ref_v.plate                                   as placa,
       concat(ref_cu.first_name, ' ', ref_cu.last_name)  as cliente,
       ref_i.stage                                   as etapa,
       ref_d.description                             as dano,
       ref_d.severity                                as severidad,
       round(ref_d.repair_cost, 2)                   as costo,
       if(ref_d.charged_to_customer, 'Sí', 'No')     as se_cobra
from damages as ref_d
join inspections as ref_i  on ref_i.id = ref_d.inspection_id
join contracts as ref_ct   on ref_ct.id = ref_i.contract_id
join reservations as ref_r on ref_r.id = ref_ct.reservation_id
join customers as ref_cu   on ref_cu.id = ref_r.customer_id
join vehicles as ref_v     on ref_v.id = ref_ct.vehicle_id
order by ref_ct.id, ref_d.id;