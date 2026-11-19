create or replace function public.expotec_admin_eliminar_desafio(p_evento_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    v_desafio record;
begin
    perform public.expotec_guard_admin();

    if p_evento_id is null
       or not exists (select 1 from public.expotec_eventos where id = p_evento_id) then
        raise exception 'El evento no existe.';
    end if;

    select * into v_desafio
    from public.expotec_desafios
    where evento_id = p_evento_id;

    if v_desafio.id is null then
        raise exception 'El evento no tiene un desafío que eliminar.';
    end if;

    if v_desafio.congelado_en is not null
       or exists (
           select 1
           from public.expotec_partidas
           where desafio_id = v_desafio.id
       ) then
        raise exception 'El desafío ya está en juego y no puede eliminarse.';
    end if;

    delete from public.expotec_desafios where id = v_desafio.id;
    return true;
end;
$$;

revoke all on function public.expotec_admin_eliminar_desafio(uuid) from public;
grant execute on function public.expotec_admin_eliminar_desafio(uuid) to authenticated;

notify pgrst, 'reload schema';
