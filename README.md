# Forever Quest Guide

Atlas de la zona actual para **World of Warcraft: Forever** (interfaz 16001). Abrí o cerrá la guía con el botón de mapa del minimapa, **/fqg**, el botón **Guía** del mapa mundial o la asignación **Abrir o cerrar la guía del mapa**. Si cruzás a otra zona con la ventana abierta, el atlas se actualiza automáticamente.

La lista de la zona queda a la izquierda. El mapa, las etapas y las recompensas de la misión seleccionada aparecen a la derecha. Podés recorrer la lista y comparar misiones sin abrir otra pantalla.

## Instalación

1. Colocá los archivos en una carpeta llamada **ForeverQuestGuide** que contenga **ForeverQuestGuide.toc** directamente.
2. Copiá esa carpeta dentro de **World of Warcraft/_forever_/Interface/AddOns/**.
3. Si WoW estaba abierto al instalar, reiniciá el cliente para que reconozca los archivos nuevos. Habilitá **Forever Quest Guide** en la selección de personaje.

La interfaz se muestra en español en clientes esES y esMX. El resto usa inglés. Los nombres propios dependen del cliente o del catálogo.

## Datos del atlas

- **Misiones.** Los inicios disponibles se ordenan por nivel. **En curso** muestra las misiones activas con ubicaciones en la zona. Se excluyen las misiones completadas y bloqueadas. El filtro de grises se guarda por personaje. Al seleccionar una misión, el mapa marca dónde aceptarla (**!**), dónde completar objetivos (**×**) y dónde entregarla (**?**). Al elegir una etapa, el mapa muestra solo sus ubicaciones. En cada fila se resume la EXP, el porcentaje del nivel actual, las monedas y los objetos cuando hay datos. La EXP estimada del catálogo se identifica con **~**. La ficha tiene tres etapas para ubicar el inicio, los objetivos y la entrega, incluso cuando los lugares están en otra zona. Las recompensas siguen visibles en su panel.
- **Equipo de misiones.** Recompensas equipables de las misiones disponibles y en curso. Debajo de cada objeto aparece su misión. Hacé clic en ese nombre o pulsá A con el objeto enfocado para abrir la ficha en Misiones. Cada fila muestra icono, ranura, tipo y nivel de objeto. El panel derecho agrega el requisito y los atributos conocidos. El mapa muestra solo los puntos de la misión seleccionada. El filtro tiene en cuenta el nivel requerido y el tipo de armadura.
- **Minería y herboristería.** Posibles ubicaciones con el requisito del recurso y la habilidad actual del personaje. **GatherLite** es una dependencia opcional. Si está instalado, la guía agrega sus puntos disponibles para el mapa actual. También incluye ubicaciones de referencia.
- **Pesca.** Especies y zonas de captura reportadas. Algunos peces tienen registro por zona sin coordenadas. Si GatherLite tiene bancos registrados, también aparecen en el atlas. Las capturas dependen de la habilidad y del lugar exacto donde pesques.

Para misiones y equipo, la guía usa **QuestieDB** (contrato 3), **NorgannonDB** (esquema 1.2 o posterior de la serie 1.x) o los datos nativos, en ese orden. El modo nativo se limita a lo que el cliente muestra en el mapa y a recompensas conocidas. Eventos, rotaciones, reputaciones y restricciones específicas pueden variar según los datos disponibles. Los puntos de recolección son ubicaciones posibles.

El mapa usa las texturas de las zonas exploradas que provee el cliente. Si el mapa mundial ya muestra la misma zona revelada por un addon de mapas, la guía también usa esas texturas. Los marcadores del minimapa usan HereBeDragons, incluido en GatherLite y Questie. Podés activarlos o desactivarlos con **/fqg minimap** si ya usás otros pines. En el minimapa se muestran los inicios disponibles y los objetivos y entregas de misiones activas.

## Mando y ratón

| Entrada | Acción |
| --- | --- |
| Cruceta arriba o abajo | Mover el foco |
| Cruceta izquierda o derecha | Cambiar de pestaña o de sección dentro de una ficha |
| LB y RB | Cambiar pestaña principal |
| LT y RT | Avanzar por páginas |
| A / ✕ | Pasar de la lista a la ficha, ver un objeto o marcar un recurso |
| B / ○ | Devolver el foco a la lista, volver a Equipo o cerrar |
| X / □ | Marcar la ubicación más cercana de la selección |
| L3 | Borrar el waypoint activo |
| Y / △ | Mostrar u ocultar misiones grises |
| R3 | Alternar entre misiones disponibles y en curso desde la lista, o entre etapas y recompensas en la ficha |

Podés asignar un botón o combinación libre para abrir la guía desde las asignaciones del juego. Con el ratón, un clic en una misión actualiza el mapa y la ficha. Hacé clic en una etapa para navegar sus ubicaciones. Un clic en un pin de misión abre la ficha y selecciona la ubicación. El clic derecho marca ese punto. En mapas que admiten marcadores personales, **Marcar punto** coloca el marcador del cliente. Para quitarlo, usá **Borrar punto**, **L3** o **/fqg clear**. La guía se cierra al entrar en combate.

## Estructura

- **Sources**, **Native**, **Character** y **Data** consultan los catálogos, el juego y la elegibilidad.
- **Gear** y **Resources** preparan equipo y profesiones por zona.
- **Entries** prepara las listas y fichas. **View** y **ZoneMap** dibujan la interfaz. **Guide** coordina navegación, eventos y posición.

## Créditos de datos

Los registros de capturas, traducciones de nodos y ubicaciones de recolección se basan en los datos de [GatherLite](https://github.com/wuild/gatherlite) de Wuild. El catálogo compacto de minería y herboristería procede del conjunto de GatherLite adaptado en Controller Forever Gathering. La licencia de atribución se incluye en **LICENSE-GatherLite.txt**. El mapa y los marcos usan recursos del cliente de WoW.
