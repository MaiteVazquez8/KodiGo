<template>
  <div class="k-screen">
    <main class="k-container pantalla">
      <p class="pantalla-titulo k-h1">Centro de Ayuda</p>
      <p class="pantalla-subtitulo">Preguntas frecuentes sobre Kodigo</p>

      <section class="ayuda-grupo">
        <h2 class="ayuda-grupo-titulo">Cuenta y acceso</h2>
        <details class="ayuda-item">
          <summary>¿Cómo recupero mi contraseña?</summary>
          <p>
            Desde el ingreso, en «¿Olvidaste tu contraseña?», ingresá tu correo y te enviamos un
            enlace para restablecerla. Si ya iniciaste sesión, en Configuración podés cambiarla
            directamente. Los invitados primero tienen que crear una cuenta.
          </p>
        </details>
        <details class="ayuda-item">
          <summary>¿Qué es una cuenta de invitado?</summary>
          <p>
            Es una sesión anónima real y única: practicás con tu propio progreso, intentos y racha,
            que se guardan en Supabase. Si creás una cuenta, esa misma sesión se convierte en tu
            cuenta y conserva tu identidad y tu progreso.
          </p>
        </details>
      </section>

      <section class="ayuda-grupo">
        <h2 class="ayuda-grupo-titulo">Progreso y clases</h2>
        <details class="ayuda-item">
          <summary>¿Cuándo se desbloquea la siguiente unidad?</summary>
          <p>
            Cuando aprobás todas las lecciones publicadas de la unidad actual. Cada cuenta tiene su
            propio desbloqueo: no depende del avance de otros estudiantes.
          </p>
        </details>
        <details class="ayuda-item">
          <summary>¿Qué necesito para aprobar una clase?</summary>
          <p>
            Al menos dos tercios de las actividades correctas, redondeando hacia arriba
            (3 → 2, 4 → 3, 5 → 4, 7 → 5). Podés reintentar sin perder tu mejor resultado.
          </p>
        </details>
        <details class="ayuda-item">
          <summary>¿Cómo funcionan los tipos de actividad?</summary>
          <p>
            Cada clase combina selección, verdadero o falso, completar, ordenar, relacionar,
            escribir código, corregir código, predecir resultados y armar con bloques. Todas se
            corrigen en el servidor: la solución nunca se muestra antes de comprobar.
          </p>
        </details>
      </section>

      <section class="ayuda-grupo">
        <h2 class="ayuda-grupo-titulo">Experiencia y logros</h2>
        <details class="ayuda-item">
          <summary>¿Cómo gano XP?</summary>
          <p>
            La primera vez que aprobás una clase ganás 20 XP más 5 por cada respuesta correcta.
            Los reintentos no vuelven a otorgar ese XP. Algunos logros también dan experiencia.
          </p>
        </details>
        <details class="ayuda-item">
          <summary>¿Por qué no aparece un logro?</summary>
          <p>
            Los logros se otorgan automáticamente al cerrar un intento. Si cumplís el objetivo y no
            aparece, cerrá un intento nuevo o recargá la pantalla de Logros.
          </p>
        </details>
      </section>

      <section class="ayuda-grupo">
        <h2 class="ayuda-grupo-titulo">Soporte técnico</h2>
        <details class="ayuda-item">
          <summary>¿Puedo usar Kodigo en el celular?</summary>
          <p>
            Sí. La interfaz es responsive y también podés usar la app Android empaquetada con
            Capacitor. Las actividades táctiles, como ordenar y armar con bloques, tienen botones
            además del arrastre.
          </p>
        </details>
        <details class="ayuda-item">
          <summary>La actividad no me deja comprobar</summary>
          <p>
            Revisá que hayas completado toda la interacción: elegir una opción, escribir el código,
            agregar bloques o cerrar todos los pares. Si el error continúa, reintentá la carga.
          </p>
        </details>
      </section>

      <RouterLink to="/mas" class="k-btn k-btn--primary k-btn--block ayuda-volver">
        Volver a Más
      </RouterLink>
    </main>
  </div>
</template>

<script setup>
import { RouterLink } from 'vue-router'
</script>

<style scoped>
.pantalla {
  display: flex;
  flex-direction: column;
  padding-top: var(--k-space-6);
}

.pantalla-titulo {
  margin-top: var(--k-space-2);
}

.pantalla-subtitulo {
  margin-top: var(--k-space-2);
  font-size: 14px;
  color: var(--k-text-2);
}

.ayuda-grupo {
  margin-top: var(--k-space-6);
}

.ayuda-grupo-titulo {
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--k-accent);
}

.ayuda-item {
  margin-top: var(--k-space-3);
  padding: var(--k-space-3) var(--k-space-4);
  border-radius: var(--k-radius-sm);
  border: 1px solid var(--k-line);
  background: var(--k-surface-2);
}

.ayuda-item summary {
  font-size: 13.5px;
  font-weight: 800;
  cursor: pointer;
}

.ayuda-item p {
  margin-top: var(--k-space-2);
  font-size: 13px;
  line-height: 1.55;
  color: var(--k-text-2);
}

.ayuda-volver {
  margin-top: var(--k-space-6);
}
</style>
