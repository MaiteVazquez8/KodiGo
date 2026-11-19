begin;

alter table public.expotec_eventos
    add column if not exists grupo_actual integer not null default 1;
alter table public.expotec_eventos
    drop constraint if exists expotec_eventos_grupo_actual_check;
alter table public.expotec_eventos
    add constraint expotec_eventos_grupo_actual_check check (grupo_actual >= 1);

update public.expotec_eventos e
set grupo_actual = greatest(
    e.grupo_actual,
    coalesce((select max(p.grupo) from public.expotec_partidas p where p.evento_id = e.id), 1)
);

create or replace function public.expotec_iniciar_partida(
    p_evento_id uuid,
    p_alias text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_usuario uuid := auth.uid();
    v_mensaje text;
    v_evento record;
    v_desafio record;
    v_participante uuid;
    v_partida_abierta uuid;
    v_partida uuid;
    v_cantidad integer;
    v_grupo integer;
    v_config jsonb;
begin
    if v_usuario is null then
        raise exception 'Se necesita una sesion para participar';
    end if;

    if not expotec_evento_ventana_abierta(p_evento_id) then
        raise exception 'El evento no está activo ahora mismo.';
    end if;

    select e.id, e.nombre, e.grupo_actual
    into v_evento
    from expotec_eventos e
    where e.id = p_evento_id
    for share;

    if v_evento.id is null then
        raise exception 'El evento no existe.';
    end if;

    v_mensaje := expotec_alias_inconveniente(p_alias);
    if v_mensaje is not null then
        raise exception '%', v_mensaje;
    end if;

    select d.id, d.nombre, d.version, d.cantidad_preguntas, d.puntos_por_correcta,
           d.tiempo_cuestionario_seg, d.duracion_juego_seg, d.vidas_juego
    into v_desafio
    from expotec_desafios d
    where d.evento_id = p_evento_id;

    if v_desafio.id is null then
        raise exception 'El evento todavía no tiene un desafío configurado.';
    end if;

    v_participante := expotec_registrar_participante(p_evento_id, p_alias);

    select p.id into v_partida_abierta
    from expotec_partidas p
    where p.usuario_id = v_usuario
      and p.evento_id = p_evento_id
      and p.estado in ('creada', 'en_cuestionario', 'cuestionario_completado', 'en_juego')
    limit 1;

    if v_partida_abierta is not null then
        return v_partida_abierta;
    end if;

    select count(*)::integer into v_cantidad
    from expotec_desafio_preguntas dp
    join preguntas q on q.id = dp.pregunta_id
    where dp.desafio_id = v_desafio.id
      and q.estado_publicacion = 'publicado'
      and q.tipo = 'seleccion'
      and btrim(coalesce(q.enunciado, '')) <> '';

    if v_cantidad < coalesce(v_desafio.cantidad_preguntas, 1) then
        raise exception 'El desafío todavía no tiene sus % preguntas configuradas. Avisá al equipo de Kodigo.',
            coalesce(v_desafio.cantidad_preguntas, 1);
    end if;

    v_cantidad := v_desafio.cantidad_preguntas;

    update expotec_desafios
    set congelado_en = coalesce(congelado_en, now())
    where id = v_desafio.id;

    v_grupo := v_evento.grupo_actual;

    v_config := jsonb_build_object(
        'evento', jsonb_build_object('id', v_evento.id, 'nombre', v_evento.nombre),
        'desafio', jsonb_build_object(
            'id', v_desafio.id,
            'nombre', v_desafio.nombre,
            'version', v_desafio.version,
            'cantidad_preguntas', v_cantidad,
            'puntos_por_correcta', v_desafio.puntos_por_correcta,
            'tiempo_cuestionario_seg', v_desafio.tiempo_cuestionario_seg,
            'duracion_juego_seg', v_desafio.duracion_juego_seg,
            'vidas_juego', v_desafio.vidas_juego
        )
    );

    insert into expotec_partidas (
        evento_id, desafio_id, participante_id, usuario_id, alias,
        estado, grupo, config_snapshot, iniciado_at, vencimiento_at
    )
    values (
        p_evento_id, v_desafio.id, v_participante, v_usuario,
        btrim(p_alias),
        'en_cuestionario',
        v_grupo,
        v_config,
        now(),
        case
            when v_desafio.tiempo_cuestionario_seg is null then null
            else now() + make_interval(secs => v_desafio.tiempo_cuestionario_seg)
        end
    )
    returning id into v_partida;

    insert into expotec_preguntas_asignadas (partida_id, pregunta_id, orden, opciones_orden)
    select
        v_partida,
        seleccionadas.id,
        seleccionadas.posicion - 1,
        mezcladas.opciones
    from (
        select pool.pregunta_id as id,
               row_number() over (order by random()) as posicion
        from (
            select dp2.pregunta_id
            from expotec_desafio_preguntas dp2
            join preguntas q2 on q2.id = dp2.pregunta_id
            where dp2.desafio_id = v_desafio.id
              and q2.estado_publicacion = 'publicado'
              and q2.tipo = 'seleccion'
              and btrim(coalesce(q2.enunciado, '')) <> ''
            order by random()
            limit v_cantidad
        ) pool
    ) seleccionadas
    cross join lateral (
        select jsonb_agg(o.id order by random()) opciones
        from opciones o
        where o.pregunta_id = seleccionadas.id
    ) mezcladas;

    return v_partida;
end;
$$;

create or replace function public.expotec_ranking(
    p_evento_id uuid,
    p_limite integer default 100
)
returns table (
    puesto bigint,
    alias varchar,
    puntaje_total integer,
    puntaje_cuestionario integer,
    puntaje_juego integer,
    correctas integer,
    incorrectas integer,
    tiempo_cuestionario_seg numeric,
    finalizado_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
    with grupo_actual as (
        select e.grupo_actual
        from public.expotec_eventos e
        where e.id = p_evento_id
    ), oficiales as (
        select r.*
        from public.expotec_resultados_publicos r
        join public.expotec_partidas p on p.id = r.partida_id
        cross join grupo_actual g
        where r.evento_id = p_evento_id
          and p.estado = 'finalizada'
          and p.grupo = g.grupo_actual
    ), mejores as (
        select distinct on (alias_normalizado) *
        from oficiales
        order by alias_normalizado,
                 puntaje_total desc,
                 tiempo_cuestionario_seg asc nulls last,
                 puntaje_juego desc,
                 finalizado_at asc
    )
    select
        row_number() over (
            order by puntaje_total desc,
                     tiempo_cuestionario_seg asc nulls last,
                     puntaje_juego desc,
                     finalizado_at asc
        ),
        alias,
        puntaje_total,
        puntaje_cuestionario,
        puntaje_juego,
        correctas,
        incorrectas,
        tiempo_cuestionario_seg,
        finalizado_at
    from mejores
    order by puntaje_total desc,
             tiempo_cuestionario_seg asc nulls last,
             puntaje_juego desc,
             finalizado_at asc
    limit least(coalesce(p_limite, 100), 500);
$$;

create or replace function public.expotec_admin_reiniciar_ranking(p_evento_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_grupo_actual integer;
    v_grupo_siguiente integer;
    v_count integer;
begin
    perform expotec_guard_admin();

    if not exists (select 1 from public.expotec_eventos where id = p_evento_id) then
        raise exception 'El evento no existe';
    end if;

    select grupo_actual into v_grupo_actual
    from public.expotec_eventos
    where id = p_evento_id
    for update;

    select greatest(v_grupo_actual, coalesce(max(grupo), 1))
    into v_grupo_actual
    from public.expotec_partidas
    where evento_id = p_evento_id;
    v_grupo_siguiente := v_grupo_actual + 1;

    update public.expotec_eventos
    set grupo_actual = v_grupo_siguiente
    where id = p_evento_id;

    update public.expotec_partidas
    set estado = 'deshabilitada', estado_anterior = estado
    where evento_id = p_evento_id
      and estado in ('finalizada', 'vencida', 'abandonada');
    get diagnostics v_count = row_count;

    update public.expotec_partidas
    set grupo = v_grupo_siguiente
    where evento_id = p_evento_id
      and estado in ('creada', 'en_cuestionario', 'cuestionario_completado', 'en_juego');

    return v_count;
end;
$$;

revoke all on function public.expotec_iniciar_partida(uuid, text) from public;
grant execute on function public.expotec_iniciar_partida(uuid, text) to authenticated;
revoke all on function public.expotec_ranking(uuid, integer) from public;
grant execute on function public.expotec_ranking(uuid, integer) to anon, authenticated;
revoke all on function public.expotec_admin_reiniciar_ranking(uuid) from public;
grant execute on function public.expotec_admin_reiniciar_ranking(uuid) to authenticated;

notify pgrst, 'reload schema';
commit;
