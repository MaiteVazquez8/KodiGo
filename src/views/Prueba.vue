<template>
    <q-layout view="hhh lpr fff">
        <q-header>
            <q-toolbar class="barra de navegación">
                <q-toolbar class="marca">
                    KodiGo
                </q-toolbar>
            </q-toolbar>
        </q-header>
        <q-page-container>
            <nav>
                <q-btn flat no-caps label="Inicio" to="/"></q-btn>
            </nav>
        </q-page-container>
    </q-layout>
</template>

<script setup>
    import { ref } from 'vue'
    import {supabase} from '@/supabase'
    
    const correo=ref('')
    const password=ref('')
    const repetirPassword=ref('')
    const cargando=ref(false)
    const mensaje=ref('')
    const registroExitoso=ref(false)

    async function registrarUsuario() {
        mensaje.value = ''
        registroExitoso.value = false
        if (password.value !== repetirPassword.value) {
            mensaje.value = 'Las contraseñas no coinciden'
            return
        }
        if (password.value.length < 6) {
            mensaje.value = 'La contraseña debe tener al menos 6 caracteres'
            return
        }

        try{
            cargando.value = true
            const { error } = await supabase.auth.signUp({
                email: correo.value,
                password: password.value,
            })
            cargando.value = false
            if (error) {
                throw error
            } else {
                registroExitoso.value = true
                mensaje.value = 'Registro realizado. Revisa tu Email.'

                correo.value = ''
                password.value = ''
                repetirPassword.value = ''
            }
        } catch (error) {
            mensaje.value=error.message
        } finally {
            cargando.value = false
        }
    }
</script>

<style scoped>

</style>