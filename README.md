# RDM Next

Rebuild de la libreria de componentes RDM sobre **Material Design 3**,
desde la capa de tokens. Carpeta hermana de `rdm/` (la libreria anterior),
que se conserva intacta como referencia y no se toca.

## Estado

Capa de tokens completa y verificada. Sin componentes todavia. Ver el
roadmap en `index.html` y el detalle de decisiones en `SKILL.md`.

## Arquitectura

Tres capas con dependencias estrictas (`ref -> sys -> comp`):

```
css/md/tokens.css    entry: importa el vendor oficial + adiciones propias
css/md/additions.css los 9 roles de superficie que el vendor no trae
css/comp/            tokens y estilos por componente (uno por vez)
css/rdm/project.css  extensiones propias (--rdm-*), nunca mezcladas con M3
css/rdm-next.css     entry del proyecto
```

Un componente nunca lee `ref` (paletas crudas). Todo valor visual viene de
`--md-sys-*` o `--md-comp-*`; lo que no es spec M3 vive en `--rdm-*`.

## Estructura

```
rdm-next/
  index.html              indice vivo del showroom (roadmap por dependencia)
  <componente>.html       una pagina por componente (se crean al construirlo)
  css/md/                 capa de tokens (entry: tokens.css)
  css/comp/               un archivo por componente
  css/rdm/                extensiones del proyecto
  css/rdm-next.css        entry del proyecto
  js/  img/
  tools/verify-tokens.ps1 verificacion de la capa de tokens (5 checks)
  vendor/material-tokens/ repo oficial de Google, podado a css/ + docs
  SKILL.md                decisiones, metodologia, convenciones e historial
```

## Principios

1. **Cero CSS inline.** Un componente = un archivo `css/comp/<nombre>.css`.
2. **HTML comentado.** Cada componente y pieza con `<!-- INICIO: x -->` /
   `<!-- FIN: x -->`.
3. **Clase base obligatoria.** `.rdm-button` + `.rdm-button--filled`, nunca
   modificadores sueltos ni selectores de etiqueta.
4. **Showroom por componente.** Una pagina por componente, un ejemplo por
   variante y estado.
5. **Un componente consume los previos.** No se reimplementa typography,
   shape ni color dentro de un componente.

El detalle completo esta en `SKILL.md` (secciones 2 a 4).

## Verificacion

```powershell
powershell -ExecutionPolicy Bypass -File tools/verify-tokens.ps1
```

Chequea referencias rotas, duplicados, sys incompleto, fugas de capa
(`comp/` o `rdm/` leyendo `--md-ref-*`) e imports. Corre en cada commit
de la capa de tokens.

## Tema

Solo `prefers-color-scheme`, sin JavaScript. El tema lo decide el sistema
operativo. Sin toggle manual a proposito: el toggle JS de la libreria
anterior dejaba tokens sin re-tematizar por una lista hardcodeada.

## Licencia

Codigo propio: el de tu proyecto. Los tokens de `vendor/` son de Google
bajo Apache License 2.0 (`vendor/material-tokens/LICENSE`). Tipografia
Roboto bajo Apache License 2.0 via Google Fonts.
