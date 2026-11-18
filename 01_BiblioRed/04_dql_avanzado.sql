-- Funciones, procedimientos y controles de negocio | BiblioRed
-- Se mantienen los datos, reglas, orden de ejecución y salidas del taller.
-- Se reorganizaron los nombres internos y la presentación del SQL.

-- 04_dql_avanzado.sql
use bibliored;

delimiter $$

-- sp_resumen_socio: préstamos activos y saldo pendiente de un socio
drop procedure if exists sp_resumen_socio $$
create procedure sp_resumen_socio(
    in  param_member_id bigint,
    out param_prestamos_activos int,
    out param_saldo_pendiente decimal(12,2)
)
begin
    declare local_found int default 0;

    select count(*) into local_found from members where id = param_member_id;
    if local_found = 0 then
        signal sqlstate '45000' set message_text = 'El socio no existe';
    end if;

    select count(*) into param_prestamos_activos
    from loans
    where member_id = param_member_id and status = 'ACTIVO';

    -- saldo = valor de cada multa PENDIENTE menos lo abonado
    select ifnull(sum(ref_f.amount - ifnull(ref_p.pagado, 0)), 0) into param_saldo_pendiente
    from fines ref_f
    join loans ref_l on ref_l.id = ref_f.loan_id
    left join (select fine_id, sum(amount) as pagado
               from fine_payments
               group by fine_id) ref_p on ref_p.fine_id = ref_f.id
    where ref_l.member_id = param_member_id and ref_f.status = 'PENDIENTE';
end $$

-- sp_prestar_ejemplar: valida en orden y registra el préstamo
drop procedure if exists sp_prestar_ejemplar $$
create procedure sp_prestar_ejemplar(
    in  param_copy_id bigint,
    in  param_member_id bigint,
    in  param_employee_id bigint,
    in  param_loaned_on date,
    out param_loan_id bigint
)
begin
    declare local_found int default 0;
    declare local_member_status varchar(20);
    declare local_membership_id bigint;
    declare local_copy_status varchar(20);
    declare local_pending int default 0;
    declare local_active int default 0;
    declare local_max_loans int;
    declare local_loan_days int;
    declare local_msg varchar(200);

    -- 1. El socio existe
    select count(*) into local_found from members where id = param_member_id;
    if local_found = 0 then
        signal sqlstate '45000' set message_text = 'El socio no existe';
    end if;

    -- 2. El socio está ACTIVO
    select status, membership_id into local_member_status, local_membership_id
    from members where id = param_member_id;
    if local_member_status <> 'ACTIVO' then
        set local_msg = concat('El socio no está activo: ', local_member_status);
        signal sqlstate '45000' set message_text = local_msg;
    end if;

    -- 3. El ejemplar existe
    select count(*) into local_found from copies where id = param_copy_id;
    if local_found = 0 then
        signal sqlstate '45000' set message_text = 'El ejemplar no existe';
    end if;

    -- 4. El ejemplar está DISPONIBLE
    select status into local_copy_status from copies where id = param_copy_id;
    if local_copy_status <> 'DISPONIBLE' then
        set local_msg = concat('El ejemplar no está disponible: ', local_copy_status);
        signal sqlstate '45000' set message_text = local_msg;
    end if;

    -- 5. El socio no tiene multas PENDIENTE
    select count(*) into local_pending
    from fines ref_f
    join loans ref_l on ref_l.id = ref_f.loan_id
    where ref_l.member_id = param_member_id and ref_f.status = 'PENDIENTE';
    if local_pending > 0 then
        signal sqlstate '45000' set message_text = 'El socio tiene multas pendientes';
    end if;

    -- 6. El socio no ha llegado al tope de su membresía
    select max_loans, loan_days into local_max_loans, local_loan_days
    from memberships where id = local_membership_id;
    select count(*) into local_active
    from loans where member_id = param_member_id and status = 'ACTIVO';
    if local_active >= local_max_loans then
        set local_msg = concat('El socio alcanzó su tope de ', local_max_loans, ' préstamos');
        signal sqlstate '45000' set message_text = local_msg;
    end if;

    -- Todo bien: PRIMERO el ejemplar, DESPUÉS el préstamo (el empleado lo valida la FK)
    update copies set status = 'PRESTADO' where id = param_copy_id;
    insert into loans (copy_id, member_id, employee_id, loaned_on, due_on)
    values (param_copy_id, param_member_id, param_employee_id, param_loaned_on,
            date_add(param_loaned_on, interval local_loan_days day));
    set param_loan_id = last_insert_id();
end $$

-- sp_devolver_ejemplar: devuelve y genera multa por mora si aplica
drop procedure if exists sp_devolver_ejemplar $$
create procedure sp_devolver_ejemplar(
    in  param_loan_id bigint,
    in  param_returned_on date,
    out param_fine_amount decimal(12,2)
)
begin
    declare local_found int default 0;
    declare local_status varchar(20);
    declare local_loaned_on date;
    declare local_due_on date;
    declare local_copy_id bigint;
    declare local_daily_fine decimal(10,2);
    declare local_late_days int default 0;

    select count(*) into local_found from loans where id = param_loan_id;
    if local_found = 0 then
        signal sqlstate '45000' set message_text = 'El préstamo no existe';
    end if;

    select ref_l.status, ref_l.loaned_on, ref_l.due_on, ref_l.copy_id, ref_ms.daily_fine
      into local_status, local_loaned_on, local_due_on, local_copy_id, local_daily_fine
    from loans ref_l
    join members ref_m      on ref_m.id = ref_l.member_id
    join memberships ref_ms on ref_ms.id = ref_m.membership_id
    where ref_l.id = param_loan_id;

    if local_status <> 'ACTIVO' then
        signal sqlstate '45000' set message_text = 'El préstamo no está activo';
    end if;

    if param_returned_on < local_loaned_on then
        signal sqlstate '45000' set message_text = 'La fecha de devolución es anterior al préstamo';
    end if;

    -- Mora calculada con la fecha de devolución recibida (nunca con la fecha del sistema)
    set local_late_days = GREATEST(datediff(param_returned_on, local_due_on), 0);
    set param_fine_amount = local_late_days * local_daily_fine;

    if local_late_days > 0 and param_fine_amount > 0 then
        insert into fines (loan_id, reason, late_days, amount, issued_on)
        values (param_loan_id, 'MORA', local_late_days, param_fine_amount, param_returned_on);
    end if;

    update loans set status = 'DEVUELTO', returned_on = param_returned_on where id = param_loan_id;
    update copies set status = 'DISPONIBLE' where id = local_copy_id;
end $$

-- sp_renovar_prestamo: valida en orden y registra la renovación
drop procedure if exists sp_renovar_prestamo $$
create procedure sp_renovar_prestamo(
    in  param_loan_id bigint,
    in  param_renewed_on date,
    out param_new_due_on date
)
begin
    declare local_found int default 0;
    declare local_status varchar(20);
    declare local_due_on date;
    declare local_title_id bigint;
    declare local_max_renewals int;
    declare local_loan_days int;
    declare local_renewals_used int default 0;
    declare local_reservations int default 0;
    declare local_msg varchar(200);

    -- 1. El préstamo existe
    select count(*) into local_found from loans where id = param_loan_id;
    if local_found = 0 then
        signal sqlstate '45000' set message_text = 'El préstamo no existe';
    end if;

    select ref_l.status, ref_l.due_on, ref_c.title_id, ref_ms.max_renewals, ref_ms.loan_days
      into local_status, local_due_on, local_title_id, local_max_renewals, local_loan_days
    from loans ref_l
    join copies ref_c       on ref_c.id = ref_l.copy_id
    join members ref_m      on ref_m.id = ref_l.member_id
    join memberships ref_ms on ref_ms.id = ref_m.membership_id
    where ref_l.id = param_loan_id;

    -- 2. Está ACTIVO
    if local_status <> 'ACTIVO' then
        signal sqlstate '45000' set message_text = 'El préstamo no está activo';
    end if;

    -- 3. No está vencido (regla 13: vencido = fecha de referencia posterior al vencimiento)
    if param_renewed_on > local_due_on then
        signal sqlstate '45000' set message_text = 'El préstamo está vencido: primero debe devolverse';
    end if;

    -- 4. No agotó las renovaciones de la membresía
    select count(*) into local_renewals_used from loan_renewals where loan_id = param_loan_id;
    if local_renewals_used >= local_max_renewals then
        set local_msg = concat('El préstamo ya usó sus ', local_max_renewals, ' renovaciones');
        signal sqlstate '45000' set message_text = local_msg;
    end if;

    -- 5. Nadie tiene una reserva PENDIENTE de ese título (en cualquier sede)
    select count(*) into local_reservations
    from reservations where title_id = local_title_id and status = 'PENDIENTE';
    if local_reservations > 0 then
        signal sqlstate '45000' set message_text = 'Hay reservas pendientes para este título';
    end if;

    -- Todo bien: nuevo vencimiento = vencimiento actual + días de la membresía
    set param_new_due_on = date_add(local_due_on, interval local_loan_days day);
    insert into loan_renewals (loan_id, renewed_on, previous_due_on, new_due_on)
    values (param_loan_id, param_renewed_on, local_due_on, param_new_due_on);
    update loans set due_on = param_new_due_on where id = param_loan_id;
end $$

-- sp_reporte_sedes: una fila por sede, recorriendo las sedes con un cursor
drop procedure if exists sp_reporte_sedes $$
create procedure sp_reporte_sedes(in param_cutoff date)
begin
    declare local_done int default 0;
    declare local_branch_id bigint;
    declare local_branch_name varchar(100);
    declare local_copies int;
    declare local_loaned int;
    declare local_overdue int;
    declare cur_branches cursor for select id, name from branches order by id;
    declare continue handler for not FOUND set local_done = 1;

    drop temporary table if exists tmp_reporte_sedes;
    create temporary table tmp_reporte_sedes (
        sede varchar(100),
        ejemplares int,
        prestados int,
        vencidos int,
        ocupacion_pct decimal(5,2)
    );

    open cur_branches;
    read_loop: loop
        fetch cur_branches into local_branch_id, local_branch_name;
        if local_done = 1 then
            leave read_loop;
        end if;

        -- ejemplares en circulación (sin perdidos ni dados de baja)
        select count(*) into local_copies
        from copies
        where branch_id = local_branch_id and status not in ('PERDIDO', 'DADO_DE_BAJA');

        -- préstamos activos de los ejemplares de la sede
        select count(*) into local_loaned
        from loans ref_l join copies ref_c on ref_c.id = ref_l.copy_id
        where ref_c.branch_id = local_branch_id and ref_l.status = 'ACTIVO';

        -- vencidos a la fecha de corte
        select count(*) into local_overdue
        from loans ref_l join copies ref_c on ref_c.id = ref_l.copy_id
        where ref_c.branch_id = local_branch_id and ref_l.status = 'ACTIVO' and ref_l.due_on < param_cutoff;

        -- sin ejemplares: ocupación vacía (NULL), sin dividir por cero
        if local_copies = 0 then
            insert into tmp_reporte_sedes values (local_branch_name, local_copies, local_loaned, local_overdue, null);
        else
            insert into tmp_reporte_sedes
            values (local_branch_name, local_copies, local_loaned, local_overdue, round(local_loaned * 100 / local_copies, 2));
        end if;
    end loop;
    close cur_branches;

    select sede, ejemplares, prestados, vencidos, ocupacion_pct
    from tmp_reporte_sedes
    order by ocupacion_pct desc, sede;

    drop temporary table tmp_reporte_sedes;
end $$

-- sp_pagar_multa: registra una cuota; el medio de pago lo rechaza la base
drop procedure if exists sp_pagar_multa $$
create procedure sp_pagar_multa(
    in  param_fine_id bigint,
    in  param_amount decimal(12,2),
    in  param_payment_method varchar(20),
    in  param_paid_on date,
    out param_balance decimal(12,2)
)
begin
    declare local_found int default 0;
    declare local_status varchar(20);
    declare local_total decimal(12,2);
    declare local_paid decimal(12,2);
    declare local_saldo decimal(12,2);

    -- 1265 = "Data truncated": error de MySQL al guardar un valor que no está en el ENUM
    declare exit handler for 1265
        signal sqlstate '45000'
        set message_text = 'Medio de pago no válido: use EFECTIVO, TARJETA o TRANSFERENCIA';

    select count(*) into local_found from fines where id = param_fine_id;
    if local_found = 0 then
        signal sqlstate '45000' set message_text = 'La multa no existe';
    end if;

    select status, amount into local_status, local_total from fines where id = param_fine_id;
    if local_status <> 'PENDIENTE' then
        signal sqlstate '45000' set message_text = 'La multa no está pendiente';
    end if;

    select ifnull(sum(amount), 0) into local_paid from fine_payments where fine_id = param_fine_id;
    set local_saldo = local_total - local_paid;
    if param_amount <= 0 or param_amount > local_saldo then
        signal sqlstate '45000' set message_text = 'El abono debe ser mayor que 0 y no superar el saldo';
    end if;

    insert into fine_payments (fine_id, amount, paid_on, payment_method)
    values (param_fine_id, param_amount, param_paid_on, param_payment_method);

    set param_balance = local_saldo - param_amount;
    if param_balance = 0 then
        update fines set status = 'PAGADA' where id = param_fine_id;
    end if;
end $$

delimiter ;

-- PRUEBAS · sp_resumen_socio
-- Prueba 1: Óscar (6), SUSPENDIDO de D4: 1 préstamo activo (1010) y saldo 3.000 (multa 3 sin abonos)
call sp_resumen_socio(6, @revision_activos, @revision_saldo);
select @revision_activos as prestamos_activos, @revision_saldo as saldo_pendiente;

-- Prueba 2: Felipe (8): 2 préstamos activos y ninguna multa => saldo 0.00
call sp_resumen_socio(8, @revision_activos, @revision_saldo);
select @revision_activos as prestamos_activos, @revision_saldo as saldo_pendiente;

-- Prueba 3: socio que no existe
-- ESPERADO: ERROR 1644 (45000): El socio no existe
-- CALL sp_resumen_socio(999, @revision_activos, @saldo);

-- PRUEBAS · sp_prestar_ejemplar (fecha 2026-11-10)
-- Prueba 1: Isabel (13) no tiene préstamos ni multas; ejemplar 6 está DISPONIBLE.
-- Vencimiento esperado: 2026-11-24 (Estudiante = 14 días)
call sp_prestar_ejemplar(6, 13, 6, '2026-11-10', @revision_prestamo);
select @revision_prestamo as prestamo_creado;
select ref_l.id, ref_l.copy_id, ref_l.loaned_on, ref_l.due_on, ref_l.status, ref_c.status as estado_ejemplar
from loans ref_l join copies ref_c on ref_c.id = ref_l.copy_id where ref_l.id = @revision_prestamo;

-- Prueba 2: Óscar (6) está SUSPENDIDO (y además debe una multa): gana la validación 2
-- ESPERADO: ERROR 1644 (45000): El socio no está activo: SUSPENDIDO
-- CALL sp_prestar_ejemplar(4, 6, 2, '2026-11-10', @revision_prestamo);

-- Prueba 3: Ricardo (12), activo, pide el ejemplar 2 que está PRESTADO
-- ESPERADO: ERROR 1644 (45000): El ejemplar no está disponible: PRESTADO
-- CALL sp_prestar_ejemplar(2, 12, 2, '2026-11-10', @revision_prestamo);

-- Prueba 4: Marcela (3), activa, con una multa pendiente, pide el ejemplar 13 (DISPONIBLE)
-- ESPERADO: ERROR 1644 (45000): El socio tiene multas pendientes
-- CALL sp_prestar_ejemplar(13, 3, 3, '2026-11-10', @revision_prestamo);

-- Prueba 5: Felipe (8, D7, Básica con 2 activos) pide el ejemplar 13 (DISPONIBLE)
-- ESPERADO: ERROR 1644 (45000): El socio alcanzó su tope de 2 préstamos
-- CALL sp_prestar_ejemplar(13, 8, 2, '2026-11-10', @revision_prestamo);

-- Prueba 6: Ricardo (12), activo, pide un ejemplar que no existe
-- ESPERADO: ERROR 1644 (45000): El ejemplar no existe
-- CALL sp_prestar_ejemplar(9999, 12, 2, '2026-11-10', @revision_prestamo);

-- PRUEBAS · sp_devolver_ejemplar
-- Prueba 1: el préstamo más atrasado de Q-02 es el 1010 (25 días × 500 = 12.500)
call sp_devolver_ejemplar(1010, '2026-11-10', @revision_multa);
select @revision_multa as multa_generada;
select id, loan_id, reason, late_days, amount, status from fines order by id desc limit 1;

-- Prueba 2: el préstamo 1012 (vence 2026-11-13) aún no vence: multa 0.00 y ninguna multa nueva
call sp_devolver_ejemplar(1012, '2026-11-10', @revision_multa);
select @revision_multa as multa_generada;
select count(*) as multas_del_prestamo_1012 from fines where loan_id = 1012;

-- Prueba 3: devolver un préstamo ya DEVUELTO (1001)
-- ESPERADO: ERROR 1644 (45000): El préstamo no está activo
-- CALL sp_devolver_ejemplar(1001, '2026-11-10', @revision_multa);

-- Prueba 4: préstamo activo (1018, prestado el 2026-10-15) con devolución anterior
-- ESPERADO: ERROR 1644 (45000): La fecha de devolución es anterior al préstamo
-- CALL sp_devolver_ejemplar(1018, '2026-10-01', @revision_multa);

-- PRUEBAS · sp_renovar_prestamo (fecha 2026-11-10)
-- Prueba 1: préstamo 1017 (Daniela, Docente): activo, al día (vence 2026-12-01),
-- 1 de 2 renovaciones usadas y su título no tiene reservas. Nuevo vencimiento = 2026-12-22
call sp_renovar_prestamo(1017, '2026-11-10', @revision_nuevo_vence);
select @revision_nuevo_vence as nuevo_vencimiento;
select * from loan_renewals where loan_id = 1017 order by id;

-- Prueba 2: préstamo 1016 (D8): ya usó sus 2 renovaciones y no está vencido
-- ESPERADO: ERROR 1644 (45000): El préstamo ya usó sus 2 renovaciones
-- CALL sp_renovar_prestamo(1016, '2026-11-10', @revision_nuevo_vence);

-- Prueba 3: préstamo 1011 (activo y vencido desde 2026-10-26)
-- ESPERADO: ERROR 1644 (45000): El préstamo está vencido: primero debe devolverse
-- CALL sp_renovar_prestamo(1011, '2026-11-10', @revision_nuevo_vence);

-- Prueba 4: préstamo 1015 (D9): título 7 con reserva PENDIENTE de Ricardo
-- ESPERADO: ERROR 1644 (45000): Hay reservas pendientes para este título
-- CALL sp_renovar_prestamo(1015, '2026-11-10', @revision_nuevo_vence);

-- PRUEBAS · sp_reporte_sedes
-- Prueba 1: reporte al corte. 5 filas, una por sede; los vencidos (1011 en Cajicá y 1018 en Chía)
-- son los que siguen activos de Q-02 (el 1010 ya se devolvió en la prueba de sp_devolver_ejemplar).
call sp_reporte_sedes('2026-11-10');
-- Prueba 2: la Sede Tabio sale con 0 | 0 | 0 y ocupacion_pct vacía (NULL), sin error de división por cero
--          (aparece en la última fila del reporte anterior).

-- PRUEBAS · sp_pagar_multa
-- Prueba 1: Marcela (3) paga completa su única multa (id 6, 600) en EFECTIVO => saldo 0.00, multa PAGADA
call sp_pagar_multa(6, 600.00, 'EFECTIVO', '2026-11-10', @revision_saldo);
select @revision_saldo as saldo_restante;
select id, status from fines where id = 6;

-- Prueba 2: Marcela repite el préstamo de la prueba 4 de sp_prestar_ejemplar: ahora sí se presta
call sp_prestar_ejemplar(13, 3, 3, '2026-11-10', @revision_prestamo);
select @revision_prestamo as prestamo_creado;

-- Prueba 3: abono parcial con TARJETA a la multa 4 (Lorena, ya tenía 20.000): 68.000 - 20.000 - 10.000 = 38.000
call sp_pagar_multa(4, 10000.00, 'TARJETA', '2026-11-10', @revision_saldo);
select @revision_saldo as saldo_restante;

-- Prueba 4: abonar a una multa PAGADA (la 1)
-- ESPERADO: ERROR 1644 (45000): La multa no está pendiente
-- CALL sp_pagar_multa(1, 100.00, 'EFECTIVO', '2026-11-10', @revision_saldo);

-- Prueba 5: abonar más que el saldo de una multa pendiente (la 3 debe 3.000)
-- ESPERADO: ERROR 1644 (45000): El abono debe ser mayor que 0 y no superar el saldo
-- CALL sp_pagar_multa(3, 20000.00, 'EFECTIVO', '2026-11-10', @revision_saldo);

-- Prueba 6: pagar con 'CHEQUE' (lo rechaza el ENUM con el error 1265 y el handler lo convierte)
-- ESPERADO: ERROR 1644 (45000): Medio de pago no válido: use EFECTIVO, TARJETA o TRANSFERENCIA
-- CALL sp_pagar_multa(3, 1000.00, 'CHEQUE', '2026-11-10', @revision_saldo);

-- Rutinas de la base: deben aparecer los 6 procedimientos
select routine_name as rutina, routine_type as tipo
from information_schema.routines
where routine_schema = 'bibliored'
order by routine_name;