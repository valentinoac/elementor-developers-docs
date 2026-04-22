# Base de datos TI para SPCC

Este diseño en PostgreSQL cubre:

- Control de acceso físico (personas, perfiles, puntos y eventos).
- Inventario general TI (laptop, mini PC HP, impresora, fotocopiadora, teclado, mouse, proyector, equipo de sonido, storage interno y cámaras).
- Gestión de cámaras de seguridad (IP y analógicas con cable) y metadatos de grabaciones.
- Stock de productos TI con movimientos de inventario.

## Archivo principal

- `spcc_ti_database.sql`

## Ejecución

```bash
psql -U <usuario> -d <base_datos> -f spcc_ti_database.sql
```

## Notas

- El script crea el esquema `spcc_ti`.
- Incluye datos base para categorías de activos, tipos de cámara y tipos de movimiento de stock.
- Puedes ampliar con tablas de mantenimiento preventivo/correctivo y proveedores si lo necesitas.
