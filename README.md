# ODOO

### Prerequisites
Hay que actualziar odoo para que no use el filestore y guarde todo lo posible en BBDD para ello hay que seguir estos pasos:

Acceder modo debug
path/web?debug=1

Acceder a: Settings > Technical > System parameters.
Crear un nuevo valor con la siguiente configuración:
    Key: ir_attachment.location
    Value: db

Si se quiere poner en alta disponibilidad hay que cambiar la siguiente label en el json de despliegue de dcos a true
"HAPROXY_0_STICKY": "false",


### More Info:
https://stratio.atlassian.net/wiki/spaces/AplicacionesInternas/
