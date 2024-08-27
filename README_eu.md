<!--
Ohart ongi: README hau automatikoki sortu da <https://github.com/YunoHost/apps/tree/master/tools/readme_generator>ri esker
EZ editatu eskuz.
-->

# XWiki YunoHost-erako

[![Integrazio maila](https://dash.yunohost.org/integration/xwiki.svg)](https://ci-apps.yunohost.org/ci/apps/xwiki/) ![Funtzionamendu egoera](https://ci-apps.yunohost.org/ci/badges/xwiki.status.svg) ![Mantentze egoera](https://ci-apps.yunohost.org/ci/badges/xwiki.maintain.svg)

[![Instalatu XWiki YunoHost-ekin](https://install-app.yunohost.org/install-with-yunohost.svg)](https://install-app.yunohost.org/?app=xwiki)

*[Irakurri README hau beste hizkuntzatan.](./ALL_README.md)*

> *Pakete honek XWiki YunoHost zerbitzari batean azkar eta zailtasunik gabe instalatzea ahalbidetzen dizu.*  
> *YunoHost ez baduzu, kontsultatu [gida](https://yunohost.org/install) nola instalatu ikasteko.*

## Aurreikuspena

XWiki is an Open Source wiki engine (LGPLv2) suitable for use by workgroups (associations, companies, etc.). The software allows the rapid creation of small applications to meet different information management needs.

**Paketatutako bertsioa:** 16.7.0~ynh1

**Demoa:** <https://playground.xwiki.org/xwiki/bin/view/Main/WebHome>

## Pantaila-argazkiak

![XWiki(r)en pantaila-argazkia](./doc/screenshots/XWiki-standard-help.jpg)

## Dokumentazioa eta baliabideak

- Aplikazioaren webgune ofiziala: <https://www.xwiki.org/>
- Erabiltzaileen dokumentazio ofiziala: <https://www.xwiki.org/xwiki/bin/view/Documentation/UserGuide/>
- Administratzaileen dokumentazio ofiziala: <https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/>
- Jatorrizko aplikazioaren kode-gordailua: <https://github.com/xwiki/xwiki-platform>
- YunoHost Denda: <https://apps.yunohost.org/app/xwiki>
- Eman errore baten berri: <https://github.com/YunoHost-Apps/xwiki_ynh/issues>

## Garatzaileentzako informazioa

Bidali `pull request`a [`testing` abarrera](https://github.com/YunoHost-Apps/xwiki_ynh/tree/testing).

`testing` abarra probatzeko, ondorengoa egin:

```bash
sudo yunohost app install https://github.com/YunoHost-Apps/xwiki_ynh/tree/testing --debug
edo
sudo yunohost app upgrade xwiki -u https://github.com/YunoHost-Apps/xwiki_ynh/tree/testing --debug
```

**Informazio gehiago aplikazioaren paketatzeari buruz:** <https://yunohost.org/packaging_apps>
