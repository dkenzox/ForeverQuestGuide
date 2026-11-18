# Forever Quest Guide

Atlas de zonas para **World of Warcraft: Forever** (interfaz 16001). Abrí o cerrá la guía con el botón de mapa del minimapa, **/fqg**, el botón **Guía** del mapa mundial o la asignación **Abrir o cerrar la guía del mapa**. El atlas sigue al personaje de forma automática. Usá **Cambiar zona** para explorar otro mapa y **Zona actual** para volver al seguimiento automático. El selector muestra el nivel recomendado y la cantidad de misiones y la EXP al nivel actual de ambos grupos de **Disponibles**. Las rutas activas tienen su propio contador. **~** indica que el total incluye estimaciones y **+** que hay recompensas de EXP pendientes de identificar. Los pines del minimapa siguen la ubicación del personaje. El filtro de eventos oculta por defecto las misiones de temporada identificadas en el catálogo, tanto en Misiones como en Equipo y en los pines. En el selector, **Adónde ir ahora** (Y) reúne en una lista la zona actual y los destinos de todos los continentes con misiones disponibles o rutas activas que encajan con el nivel del personaje. Los dos modos incluyen una vista previa del mapa, el número de misiones disponibles y la EXP esperada. **Adónde ir ahora** ordena por EXP esperada. Las zonas de la otra facción se muestran al final.

La lista de la zona queda a la izquierda. El mapa, las etapas y las recompensas de la misión seleccionada aparecen a la derecha. Podés recorrer la lista y comparar misiones sin abrir otra pantalla.

## Instalación

1. Colocá los archivos en una carpeta llamada **ForeverQuestGuide** que contenga **ForeverQuestGuide.toc** directamente.
2. Copiá esa carpeta dentro de **World of Warcraft/_forever_/Interface/AddOns/**.
3. Si WoW estaba abierto al instalar, reiniciá el cliente para que reconozca los archivos nuevos. Habilitá **Forever Quest Guide** en la selección de personaje.

La interfaz se muestra en español en clientes esES y esMX. El resto usa inglés. Los nombres propios dependen del cliente o del catálogo.

## Datos del atlas

- **Misiones.** **Disponibles** agrupa las misiones que empiezan en la zona y las que empiezan en otra zona pero tienen objetivos o una entrega aquí. Podés plegar ambos grupos y cada zona de inicio. Las misiones se ordenan por nivel dentro de cada grupo. **Buscar misiones** filtra Disponibles y En curso por texto en el título, los objetivos y los nombres asociados a sus ubicaciones. **En curso** muestra las misiones activas con ubicaciones en la zona. Se excluyen las misiones completadas y bloqueadas. Los filtros de triviales y mazmorras se guardan por personaje y se comparten con Equipo. Al seleccionar una misión, el mapa marca dónde aceptarla (**!**), dónde completar objetivos (**×**) y dónde entregarla (**?**). Al elegir una etapa, el mapa muestra solo sus ubicaciones. En cada fila se resume la EXP, el porcentaje del nivel actual, las monedas y los objetos cuando hay datos. La EXP estimada del catálogo se identifica con **~**. La ficha tiene tres etapas para ubicar el inicio, los objetivos y la entrega, incluso cuando los lugares están en otra zona. Las recompensas siguen visibles en su panel.
- **Equipo de misiones.** Recompensas equipables de las misiones disponibles y en curso. Debajo de cada objeto aparece su misión. Hacé clic en ese nombre o pulsá A con el objeto enfocado para ver la ficha en Equipo. Cada fila muestra icono, ranura, tipo y nivel de objeto. El panel derecho agrega el requisito y los atributos conocidos. El mapa muestra solo los puntos de la misión seleccionada. El filtro tiene en cuenta el nivel requerido y el tipo de armadura.
- **Minería y herboristería.** Posibles ubicaciones con el requisito del recurso y la habilidad actual del personaje. **GatherLite** es una dependencia opcional. Si está instalado, la guía agrega sus puntos disponibles para el mapa actual. También incluye ubicaciones de referencia.
- **Pesca.** Especies y zonas de captura reportadas. Algunos peces tienen registro por zona sin coordenadas. Si GatherLite tiene bancos registrados, también aparecen en el atlas. Las capturas dependen de la habilidad y del lugar exacto donde pesques.

Para misiones y equipo, la guía usa **QuestieDB** (contrato 3), **NorgannonDB** (esquema 1.2 o posterior de la serie 1.x) o los datos nativos, en ese orden. El modo nativo se limita a lo que el cliente muestra en el mapa y a recompensas conocidas. Eventos, rotaciones, reputaciones y restricciones específicas pueden variar según los datos disponibles. Los puntos de recolección son ubicaciones posibles.

La vista previa y el atlas usan las texturas exploradas del cliente y completan las áreas sin explorar con las referencias de OpenMap cuando hay datos para el mapa. Los marcadores del minimapa usan HereBeDragons, incluido en GatherLite y Questie. Podés activarlos o desactivarlos con **/fqg minimap** si ya usás otros pines. En el minimapa se muestran los inicios disponibles y los objetivos y entregas de misiones activas.

Las misiones con vínculos en el catálogo muestran **Cadena**. Abrila desde la ficha de la misión (o con **Y** en el mando) para ver requisitos previos, continuaciones, rutas y las recompensas de cada paso. **B** vuelve a la ruta de la misión original.

## Mando y ratón

| Entrada | Acción |
| --- | --- |
| Cruceta arriba o abajo | Mover el foco |
| Cruceta izquierda o derecha | Cambiar de pestaña o de sección dentro de una ficha |
| LB y RB | Cambiar pestaña principal |
| LT y RT | Avanzar por páginas |
| A / ✕ | Plegar o desplegar un grupo, pasar a la ficha, ver un objeto o marcar un recurso |
| Menú / Start | Abrir el selector de zonas |
| B / ○ | Devolver el foco a la lista, volver a Equipo o cerrar |
| X / □ | Marcar la ubicación más cercana de la selección |
| L3 | Borrar el waypoint activo |
| Y / △ | Mostrar u ocultar misiones grises |
| Vista / Select | Elegir entre los filtros de mazmorras y eventos. Izquierda o derecha para elegir, A para alternar y B para volver |
| R3 | Alternar entre misiones disponibles y en curso desde la lista, o entre etapas y recompensas en la ficha |

Podés asignar un botón o combinación libre para abrir la guía desde las asignaciones del juego. Con el ratón, un clic en una misión actualiza el mapa y la ficha. Hacé clic en una etapa para navegar sus ubicaciones. Un clic en un pin de misión abre la ficha y selecciona la ubicación. El clic derecho marca ese punto. En mapas que admiten marcadores personales, **Marcar punto** coloca el marcador del cliente. Para quitarlo, usá **Borrar punto**, **L3** o **/fqg clear**. La guía se cierra al entrar en combate.

## Estructura

- **Sources**, **Native**, **Character** y **Data** consultan los catálogos, el juego y la elegibilidad.
- **Gear** y **Resources** preparan equipo y profesiones por zona.
- **Entries** prepara las listas y fichas. **View**, **ZonePicker** y **ZoneMap** dibujan la interfaz. **Guide** coordina navegación, eventos y posición.

## Créditos de datos

Los niveles recomendados de referencia proceden de [OpenMap](https://github.com/openmap-world/openmap) y se usan cuando el cliente no devuelve un rango. La licencia MIT se incluye en **LICENSE-OpenMap.txt**. Los rangos con **~** se estiman con los niveles de las misiones que empiezan en esa zona según QuestieDB.

Los registros de capturas, traducciones de nodos y ubicaciones de recolección se basan en los datos de [GatherLite](https://github.com/wuild/gatherlite) de Wuild. El catálogo compacto de minería y herboristería procede del conjunto de GatherLite adaptado en Controller Forever Gathering. La licencia de atribución se incluye en **LICENSE-GatherLite.txt**. El mapa y los marcos usan recursos del cliente de WoW.
