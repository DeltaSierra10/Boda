# Alba & Mateo — espacio de boda

Prototipo web adaptable para gestionar una boda. Abre `index.html` en un navegador moderno. Los datos de invitados, mesas e invitación se guardan en el almacenamiento local de ese navegador, así que el prototipo conserva los cambios en el mismo dispositivo.

## Funcionalidad incluida

- Panel resumen con confirmaciones, pendientes y notas de alergias.
- Alta y edición de invitados, estado de asistencia, acompañantes, mesa y alergias.
- Filtros y exportación CSV de la lista.
- Plano de mesas redondas o cuadradas, con aforo configurable y color de estado por invitado.
- Editor de invitación con vista previa y acción para copiar el enlace.
- Vista de roles con un súper administrador protegido visualmente y organizadores.

## Antes de publicar

Esta versión es una maqueta funcional de frontend; todavía no tiene servidor ni autenticación. El panel de equipo es demostrativo y no inicia sesión ni envía invitaciones reales. El enlace copiado abre la web, pero las respuestas que se agreguen desde esta maqueta solo se guardan en el navegador que la usa y no se comparten con los organizadores.

Para que los invitados respondan desde sus móviles y que la familia comparta los datos, hace falta conectar un backend con base de datos y autenticación (por ejemplo, Supabase o Firebase), aplicar permisos en el servidor y desplegar la web en un dominio público. Allí se implementaría el rol propietario inmutable para el resto del equipo, los accesos de organizadores y el formulario público de RSVP. No se deben guardar contraseñas en esta página estática.
