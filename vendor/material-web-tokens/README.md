# material-web-tokens

Referencia de tokens `comp` de Material Web (codigo SCSS, Apache 2.0).
Origen: https://github.com/material-components/material-web
(`labs/card` + `tokens` v0_192).

- Capa: `comp` (valores por componente y variante). No es `ref` ni `sys`.
- Formato: SCSS con funciones `map.get(...)`. El navegador no ejecuta
  Sass: estos archivos NUNCA se importan desde `css/`. Solo se leen en
  auditorias (check 41) y se documentan en los showrooms.
- Generacion: v0_192 (2023). Distinta del export DSP pre-2023 de
  `material-tokens/`: no se unifican porque la separacion registra las
  dos generaciones (ver SKILL decision 4).
- Contenido actual: `_md-comp-{elevated,filled,outlined}-card.scss`
  (wrappers con la lista de tokens soportados y los 2 TODOs de Google)
  + `versions/v0_192/` (sets de valores) + `labs/card/demo/stories.ts`
  (maquetacion de referencia: content con padding 16 y gap 16, img con
  height 128 sin aspect-ratio y border-radius inherit).
- Licencia: Apache 2.0 (`LICENSE` en esta carpeta; cada archivo trae su
  cabecera SPDX).
