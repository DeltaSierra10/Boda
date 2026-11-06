# Alba & Mateo — espacio de boda

Web estática con HTML, CSS y JavaScript, publicada con GitHub Pages y conectada a Supabase.

## Archivos

- `index.html`, `styles.css`, `auth.css`, `app.js`: web, estilos, inicio de sesión y RSVP.
- `supabase-config.js`: URL del proyecto y clave publishable (la clave publishable está diseñada para ser pública; la seguridad real la aplican Auth y RLS).
- `supabase/schema.sql`: esquema inicial para crear tablas, roles, permisos y el endpoint seguro de RSVP.
- `supabase/public-invitation-policy.sql`: permiso de lectura pública limitado a los detalles de la invitación.

## Uso

Abre la web desplegada para iniciar sesión como miembro. El súper administrador puede crear y editar fichas en Invitados; los organizadores pueden consultar la lista, asignar mesas y editar la invitación. Para invitar a una persona, usa el botón **Enlace** de su fila para copiar su URL personal de confirmación. La persona invitada responde desde ese enlace sin poder consultar el resto de la lista.

## Seguridad

No pongas contraseñas, `sb_secret_...` ni `service_role` en el frontend o en GitHub. No habilites acceso directo anónimo a invitados o mesas. Las tablas privadas usan Row Level Security; la respuesta pública se procesa con una función que solo actualiza la ficha asociada al token aleatorio de la invitación.
