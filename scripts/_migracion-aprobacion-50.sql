-- ===============================================================
-- Migración 50/50: baja el porcentaje mínimo para aprobar una lección
-- de 2/3 (~67%) a 1/2 (50%).
-- Se aplica sobre un DB que YA tiene la migración 2/3 aplicada.
-- Idempotente.
-- ===============================================================
--
-- Solo reemplaza el cuerpo de una función (la regla vive ahí). Sin tablas
-- nuevas, sin columnas nuevas.
-- ===============================================================

create or replace function recalcular_intento(p_intento_id uuid)
returns table (
    total integer,
    correctas integer,
    incorrectas integer,
    porcentaje numeric,
    completado boolean,
    aprobado boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid;
    v_leccion uuid;
    v_total integer;
    v_correctas integer;
    v_respondidas integer;
    v_estado varchar;
begin
    select i.usuario_id, i.leccion_id
    into v_usuario, v_leccion
    from intentos i
    where i.id = p_intento_id
      and i.usuario_id = auth.uid();

    if v_usuario is null then
        raise exception 'El intento no existe o no pertenece al usuario';
    end if;

    select estado into v_estado from intentos where id = p_intento_id;

    v_total := cantidad_preguntas_publicadas(v_leccion);
    select count(*)::integer,
           count(*) filter (where r.correcta)::integer
    into v_respondidas, v_correctas
    from respuestas_intento r
    where r.intento_id = p_intento_id;

    total := v_total;
    correctas := v_correctas;
    incorrectas := greatest(v_respondidas - v_correctas, 0);
    porcentaje := case
        when v_total = 0 then 0
        else round(v_correctas::numeric * 100 / v_total, 2)
    end;
    completado := v_total > 0 and v_respondidas >= v_total;
    -- Regla general: mitad de las actividades correctas, techo.
    aprobado := completado and v_correctas >= ceiling(v_total::numeric * 1 / 2)::integer;

    return next;
end;
$$;

revoke all on function recalcular_intento(uuid) from public;
