-- Pruebas transaccionales, confirmación y reversión | BiblioRed
-- Se mantienen los datos, reglas, orden de ejecución y salidas del taller.
-- Se reorganizaron los nombres internos y la presentación del SQL.

-- 05_tcl.sql
use bibliored;

-- T1 · El ejemplar sin ficha
-- Estado del ejemplar ANTES de la llamada (debe ser DISPONIBLE)
select id, barcode, status as estado_antes_de_la_llamada from copies where id = 4;

-- ---- Paso 1: SIN transacción ----
-- ESPERADO: ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails
--  (loans.employee_id -> employees.id). El empleado 999 no existe.
-- CALL sp_prestar_ejemplar(4, 12, 999, '2026-11-10', @revision_prestamo);

-- Estado del ejemplar DESPUÉS del error (si ejecutaste la llamada: queda PRESTADO)
select id, barcode, status as estado_despues_del_error from copies where id = 4;

-- Ejemplares PRESTADO que no tienen un préstamo ACTIVO (violación de la regla 12)
-- Si ejecutaste la llamada fallida, aparece el ejemplar 4. Si no, devuelve 0 filas.
select ref_c.id, ref_c.barcode, ref_c.status
from copies ref_c
where ref_c.status = 'PRESTADO'
    and not exists (select 1 from loans ref_l where ref_l.copy_id = ref_c.id and ref_l.status = 'ACTIVO');

-- Corrección: UPDATE con su SELECT previo (filtra por la clave primaria por Safe Updates)
select id, barcode, status from copies where id = 4 and status = 'PRESTADO';
update copies set status = 'DISPONIBLE' where id = 4 and status = 'PRESTADO';
select id, barcode, status as estado_tras_la_correccion from copies where id = 4;

-- ---- Paso 2: CON transacción ----
start transaction;
-- ESPERADO: ERROR 1452 (23000): igual que en el paso 1
-- CALL sp_prestar_ejemplar(4, 12, 999, '2026-11-10', @revision_prestamo);
-- Dentro de la transacción (si ejecutaste la llamada: PRESTADO; el UPDATE del ejemplar aún no se confirmó)
select id, barcode, status as estado_dentro_de_la_transaccion from copies where id = 4;
rollback;
-- Después del ROLLBACK: DISPONIBLE otra vez
select id, barcode, status as estado_despues_del_rollback from copies where id = 4;

-- Pregunta: ¿por qué en el paso 1 no se deshizo solo el cambio del ejemplar si el procedimiento falló?
-- Respuesta: porque no había transacción abierta y MySQL trabaja en autocommit. El UPDATE del ejemplar
-- fue una sentencia que terminó bien y quedó confirmada sola, en ese mismo instante. El error llegó
-- después, en el INSERT del préstamo, y solo deshace esa sentencia fallida (no las anteriores).
-- Un procedimiento no es atómico por sí mismo: sin START TRANSACTION no existe un "todo o nada".

-- T2 · sp_prestar_ejemplar_tx: todo o nada
delimiter $$

drop procedure if exists sp_prestar_ejemplar_tx $$
create procedure sp_prestar_ejemplar_tx(
    in  param_copy_id bigint,
    in  param_member_id bigint,
    in  param_employee_id bigint,
    in  param_loaned_on date,
    out param_loan_id bigint
)
begin
    -- Cualquier error (de negocio o de MySQL): deshace todo y relanza EL MISMO error
    declare exit handler for SQLEXCEPTION
    begin
        rollback;
        RESIGNAL;
    end;

    start transaction;
    call sp_prestar_ejemplar(param_copy_id, param_member_id, param_employee_id, param_loaned_on, param_loan_id);
    commit;
end $$

delimiter ;

-- Evidencia ANTES de las tres llamadas
select count(*) as prestamos_antes, max(id) as ultimo_prestamo_antes from loans;

-- Caso 1: el empleado no existe => falla con el error de la base; el ejemplar sigue DISPONIBLE
-- ESPERADO: ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails
-- CALL sp_prestar_ejemplar_tx(4, 12, 999, '2026-11-10', @revision_prestamo);
select id, barcode, status as estado_tras_el_caso_1 from copies where id = 4;   -- DISPONIBLE

-- Caso 2: el ejemplar 2 está PRESTADO
-- ESPERADO: ERROR 1644 (45000): El ejemplar no está disponible: PRESTADO
-- CALL sp_prestar_ejemplar_tx(2, 12, 2, '2026-11-10', @revision_prestamo);

-- Caso 3: préstamo correcto con un empleado que sí existe (2)
call sp_prestar_ejemplar_tx(4, 12, 2, '2026-11-10', @revision_prestamo);
select @revision_prestamo as prestamo_del_caso_3;
select id, barcode, status as estado_tras_el_caso_3 from copies where id = 4;   -- PRESTADO

-- Evidencia DESPUÉS de las tres llamadas
select count(*) as prestamos_despues, max(id) as ultimo_prestamo_despues from loans;

-- Comprobación final (regla 12): la cantidad de PRESTADO debe ser igual a la de ACTIVO
select (select count(*) from copies where status = 'PRESTADO') as ejemplares_prestados,
        (select count(*) from loans where status = 'ACTIVO')     as prestamos_activos;

-- Pregunta: ¿por qué el número del préstamo del caso 3 no es el siguiente al último préstamo que existía?
-- Respuesta: porque el contador AUTO_INCREMENT de InnoDB NO se devuelve con un ROLLBACK ni con un INSERT fallido. 

-- Cada intento de INSERT en loans (incluidos los que fallaron por la FK del empleado en T1 y en el caso 1) reservó un número que quedó "gastado".
-- Por eso el préstamo del caso 3 sale con un número mayor que MAX(id)+1: hay huecos en la numeración, pero los ids siguen siendo únicos.