-- Consultas para los casos solicitados | BiblioRed
-- Se mantienen los datos, reglas, orden de ejecución y salidas del taller.
-- Se reorganizaron los nombres internos y la presentación del SQL.

-- 03_dql.sql
-- 12 preguntas de negocio. Fecha de corte: 2026-11-10 (fija). no se usa la del sistema.
use bibliored;

-- Consulta Q-01 · ¿A qué socios no podemos llamar o no podemos atender?
-- Sin teléfono (NULL) o no activos. IFNULL muestra vacío cuando no tiene teléfono.
-- Resultado esperado: ids 4, 5 (menores sin teléfono), 6 (suspendido), 10 (inactivo)
select ref_m.id,
       concat(ref_m.first_name, ' ', ref_m.last_name) as socio,
       ref_m.status as estado,
       ifnull(ref_m.phone, '') as telefono
from members ref_m
where ref_m.phone is null or ref_m.status <> 'ACTIVO'
order by ref_m.id;

-- Consulta Q-02 · ¿Qué préstamos están vencidos al corte?
-- Vencido = ACTIVO y due_on < corte (el mismo día del vencimiento NO está vencido).
-- Multa estimada = días de mora × multa por día de la membresía del socio.
-- Resultado esperado: 1010 (25 días, 12.500), 1011 (15 días, 4.500), 1018 (12 días, 3.600)
select ref_l.id as prestamo,
       concat(ref_m.first_name, ' ', ref_m.last_name) as socio,
       ref_ms.name as membresia,
       ref_t.name as titulo,
       ref_c.barcode as ejemplar,
       ref_b.name as sede,
       ref_l.due_on as vence,
       datediff('2026-11-10', ref_l.due_on) as dias_mora,
       datediff('2026-11-10', ref_l.due_on) * ref_ms.daily_fine as multa_estimada
from loans ref_l
join members ref_m      on ref_m.id = ref_l.member_id
join memberships ref_ms on ref_ms.id = ref_m.membership_id
join copies ref_c       on ref_c.id = ref_l.copy_id
join titles ref_t       on ref_t.id = ref_c.title_id
join branches ref_b     on ref_b.id = ref_c.branch_id
where ref_l.status = 'ACTIVO'
  and ref_l.due_on < '2026-11-10'
order by dias_mora desc, ref_l.id;

-- Consulta Q-03 · ¿Qué títulos tienen coautores?
-- Se cuentan las filas de la tabla puente por título y se filtra con HAVING (> 1).
-- Resultado esperado: títulos 1, 4 y 6, con 2 autores cada uno
select ref_t.name as titulo,
       count(ref_ta.id) as autores
from titles ref_t
join title_authors ref_ta on ref_ta.title_id = ref_t.id
group by ref_t.id, ref_t.name
having count(ref_ta.id) > 1
order by ref_t.id;

-- Consulta Q-04 · ¿Qué sedes tienen más movimiento?
-- La sede del préstamo es la del ejemplar. Solo sedes con 5 o más préstamos.
-- COUNT(CASE ...) cuenta los activos sin duplicar; COUNT(DISTINCT) los socios distintos.
-- Resultado esperado: Sede Central Chía (9, 5, 6) y Sede Cajicá (5, 4, 4)
select ref_b.name as sede,
       count(ref_l.id) as prestamos_totales,
       count(case when ref_l.status = 'ACTIVO' then 1 end) as prestamos_activos,
       count(distinct ref_l.member_id) as socios_distintos
from branches ref_b
join copies ref_c on ref_c.branch_id = ref_b.id
join loans ref_l  on ref_l.copy_id = ref_c.id
group by ref_b.id, ref_b.name
having count(ref_l.id) >= 5
order by prestamos_totales desc, ref_b.name;

-- Consulta Q-05 · ¿Qué socios se afiliaron y nunca han pedido un libro?
-- NOT EXISTS permite encontrar socios que no figuran en la tabla de préstamos.
-- Resultado esperado: ids 12 (Ricardo) y 13 (Isabel)
select ref_m.id,
       concat(ref_m.first_name, ' ', ref_m.last_name) as socio,
       ref_m.joined_on as afiliado_desde
from members ref_m
where not exists (
    select 1
    from loans ref_l
    where ref_l.member_id = ref_m.id
)
order by ref_m.id;

-- Consulta Q-06 · ¿Qué tenemos en el catálogo que no se está usando?
-- Dos listados unidos: categorías sin títulos y autores sin títulos.
-- Resultado esperado: categoria / Cómic y autor / Ignacio Salazar Pinto
select 'categoria' as tipo, ref_c.name as nombre
from categories ref_c
left join titles ref_t on ref_t.category_id = ref_c.id
where ref_t.id is null
union all
select 'autor' as tipo, ref_a.full_name as nombre
from authors ref_a
left join title_authors ref_ta on ref_ta.author_id = ref_a.id
where ref_ta.id is null;

-- Consulta Q-07 · ¿Qué socios tienen al menos una multa pendiente?
-- EXISTS evita repetir al socio aunque tenga varias multas.
-- Resultado esperado: ids 3 (Marcela), 6 (Óscar), 11 (Lorena)
select ref_m.id,
       concat(ref_m.first_name, ' ', ref_m.last_name) as socio,
       ref_m.status as estado
from members ref_m
where exists (select 1
              from fines ref_f
              join loans ref_l on ref_l.id = ref_f.loan_id
              where ref_l.member_id = ref_m.id
                and ref_f.status = 'PENDIENTE')
order by ref_m.id;

-- Consulta Q-08 · ¿Qué reservas pendientes siguen en espera?
-- PENDIENTE y sin ningún ejemplar DISPONIBLE del título en la sede de recogida.
-- Resultado esperado: reservas 3 (La ciudad sin relojes, Chía) y 4 (El mapa de los ríos, Cota).
-- La reserva 1 sí se puede entregar (ejemplar 7 disponible en Chía); la 2 ya está VENCIDA.
select ref_r.id as reserva,
       concat(ref_m.first_name, ' ', ref_m.last_name) as socio,
       ref_t.name as titulo,
       ref_b.name as sede,
       ref_r.expires_on as expira
from reservations ref_r
join members ref_m  on ref_m.id = ref_r.member_id
join titles ref_t   on ref_t.id = ref_r.title_id
join branches ref_b on ref_b.id = ref_r.branch_id
where ref_r.status = 'PENDIENTE'
  and not exists (select 1
                  from copies ref_c
                  where ref_c.title_id = ref_r.title_id
                    and ref_c.branch_id = ref_r.branch_id
                    and ref_c.status = 'DISPONIBLE')
order by ref_r.id;

-- Consulta Q-09 · ¿Qué títulos son más caros de reponer que el promedio?
-- Subconsulta escalar con el promedio de todo el catálogo (55.500).
-- Resultado esperado: 5 títulos (90.000, 85.000, 68.000, 60.000, 58.000)
select ref_t.name as titulo,
       ref_t.replacement_cost as costo_reposicion
from titles ref_t
where ref_t.replacement_cost > (select avg(replacement_cost) from titles)
order by ref_t.replacement_cost desc, ref_t.name;

-- Consulta Q-10 · ¿Quiénes son los socios más asiduos?
-- Todos los que igualan el máximo de préstamos (maneja empates).
-- Resultado esperado: ids 1 (Camila) y 9 (Daniela), con 3 préstamos cada uno
select ref_m.id,
       concat(ref_m.first_name, ' ', ref_m.last_name) as socio,
       count(ref_l.id) as prestamos
from members ref_m
join loans ref_l on ref_l.member_id = ref_m.id
group by ref_m.id, ref_m.first_name, ref_m.last_name
having count(ref_l.id) = (select max(conteo)
                      from (select count(*) as conteo
                            from loans
                            group by member_id) as ref_por_socio)
order by ref_m.id;

-- Consulta Q-11 · ¿Cuál es el ejemplar más antiguo de cada sede?
-- Se compara la fecha de adquisición con el mínimo de su propia sede.
-- Tabio no aparece porque no tiene ejemplares.
-- Resultado esperado: BR-0007 (Chía), BR-0014 (Cajicá), BR-0016 (Zipaquirá, 2011), BR-0025 (Cota)
select ref_b.name as sede,
       ref_c.barcode as ejemplar,
       ref_t.name as titulo,
       ref_c.acquired_on as adquirido
from copies ref_c
join branches ref_b on ref_b.id = ref_c.branch_id
join titles ref_t   on ref_t.id = ref_c.title_id
where ref_c.acquired_on = (select min(ref_c2.acquired_on)
                       from copies ref_c2
                       where ref_c2.branch_id = ref_c.branch_id)
order by ref_b.id, ref_c.id;

-- Consulta Q-12 · ¿Cuánto debe cada socio en multas?
-- Las cuotas se suman primero por multa (subconsulta p) para no duplicar totales
-- cuando una multa tiene varias cuotas. Se excluyen las ANULADAS.
-- Solo socios con saldo > 0 (la multa pagada en dos cuotas, de Daniela, no aparece).
-- Resultado esperado: Lorena (68.000 / 20.000 / 48.000), Óscar (3.000 / 0 / 3.000), Marcela (600 / 0 / 600)
select ref_m.id,
       concat(ref_m.first_name, ' ', ref_m.last_name) as socio,
       round(sum(ref_f.amount), 2) as total_multas,
       round(sum(ifnull(ref_p.pagado, 0)), 2) as pagado,
       round(sum(ref_f.amount - ifnull(ref_p.pagado, 0)), 2) as saldo
from fines ref_f
join loans ref_l   on ref_l.id = ref_f.loan_id
join members ref_m on ref_m.id = ref_l.member_id
left join (select fine_id, sum(amount) as pagado
           from fine_payments
           group by fine_id) ref_p on ref_p.fine_id = ref_f.id
where ref_f.status <> 'ANULADA'
group by ref_m.id, ref_m.first_name, ref_m.last_name
having saldo > 0
order by saldo desc, ref_m.id;