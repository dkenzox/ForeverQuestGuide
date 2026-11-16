# Forever Quest Guide

Atlas de la zona actual para **World of Warcraft: Forever** (interfaz 16001). Abrí la guía con **/fqg**, el botón **Guía** del mapa mundial o la asignación **Abrir o cerrar la guía del mapa**. Si cruzás a otra zona con la ventana abierta, el atlas se actualiza automáticamente.

## Instalación

1. Colocá los archivos en una carpeta llamada **ForeverQuestGuide** que contenga **ForeverQuestGuide.toc** directamente.
2. Copiá esa carpeta dentro de **World of Warcraft/_forever_/Interface/AddOns/**.
3. Si WoW estaba abierto al instalar, reiniciá el cliente para que reconozca los archivos nuevos. Habilitá **Forever Quest Guide** en la selección de personaje.

La interfaz se muestra en español en clientes esES y esMX. El resto usa inglés. Los nombres propios dependen del cliente o del catálogo.

## Datos del atlas

- **Misiones.** Inicios de la zona que cumplen los requisitos conocidos del personaje, ordenados por nivel. Se excluyen misiones completadas, en curso y bloqueadas. El filtro de grises se guarda por personaje. La ficha muestra iniciadores, objetivos, entregas y recompensas registradas.
- **Equipo.** Armas y armaduras equipables, con icono, ranura, tipo y nivel de objeto. Incluye recompensas de misiones disponibles, botín identificado y vendedores del catálogo. Filtra por nivel requerido, tipo de armadura y, cuando los datos lo indican, facción del vendedor y nivel de la criatura de origen. La ficha del objeto del cliente muestra sus restricciones particulares.
- **Minería y herboristería.** Posibles ubicaciones con el requisito del recurso y la habilidad actual del personaje. **GatherLite** es una dependencia opcional. Si está instalado, la guía agrega sus puntos disponibles para el mapa actual. También incluye ubicaciones de referencia.
- **Pesca.** Especies y zonas de captura reportadas. Algunos peces tienen registro por zona sin coordenadas. Si GatherLite tiene bancos registrados, también aparecen en el atlas. Las capturas dependen de la habilidad y del lugar exacto donde pesques.

Para misiones y equipo, la guía usa **QuestieDB** (contrato 3), **NorgannonDB** (esquema 1.2 o posterior de la serie 1.x) o los datos nativos, en ese orden. El modo nativo se limita a lo que el cliente muestra en el mapa y a recompensas conocidas. Eventos, rotaciones, reputaciones y restricciones específicas pueden variar según los datos disponibles. Los puntos de recolección son ubicaciones posibles.

## Mando y ratón

| Entrada | Acción |
| --- | --- |
| Cruceta arriba o abajo | Mover el foco |
| Cruceta izquierda o derecha / LB y RB | Cambiar pestaña |
| LT y RT | Avanzar por páginas |
| A / ✕ | Abrir ficha o marcar un recurso |
| B / ○ | Volver o cerrar |
| X / □ | Marcar la ubicación más cercana de la selección |
| Y / △ | Mostrar u ocultar misiones grises |

Podés asignar un botón o combinación libre para abrir la guía desde las asignaciones del juego. Con el ratón, un clic enfoca una fila y el siguiente abre su ficha. Un clic en el mapa enfoca el resultado y el clic derecho marca ese punto. En mapas que admiten marcadores personales, **Marcar punto** coloca el marcador del cliente. La guía se cierra al entrar en combate.

## Estructura

- **Sources**, **Native**, **Character** y **Data** consultan los catálogos, el juego y la elegibilidad.
- **Gear** y **Resources** preparan equipo y profesiones por zona.
- **Entries** prepara las listas y fichas. **View** y **ZoneMap** dibujan la interfaz. **Guide** coordina navegación, eventos y posición.

## Créditos de datos

Los registros de capturas, traducciones de nodos y ubicaciones de recolección se basan en los datos de [GatherLite](https://github.com/wuild/gatherlite) de Wuild. El catálogo compacto de minería y herboristería procede del conjunto de GatherLite adaptado en Controller Forever Gathering. La licencia de atribución se incluye en **LICENSE-GatherLite.txt**. El mapa y los marcos usan recursos del cliente de WoW.
