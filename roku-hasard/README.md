# What2Watch (app Roku) — v2.1

Tu choisis une catégorie (Films, Séries, Animés…) et l'app tire au hasard un titre
de **ta** liste, avec son affiche et son résumé. La liste se gère depuis n'importe
quel téléphone ou ordi du même Wi-Fi, grâce à une page web servie par la Roku.

## Installation (mode développeur)

1. **Activer le mode développeur** : avec la télécommande, tape
   `Accueil ×3, Haut ×2, Droite, Gauche, Droite, Gauche, Droite`.
   Note l'adresse IP affichée, accepte, choisis un mot de passe (la Roku redémarre).
2. Sur ton PC, ouvre `http://IP-DE-LA-ROKU` (utilisateur : `rokudev`, mot de passe : celui choisi).
3. Clique **Upload**, choisis `dist/what2watch.zip`, puis **Install with zip** (ou **Replace**).
4. L'app se lance et apparaît dans la liste des chaînes (« What2Watch », tout à la fin).

> Mise à jour depuis une ancienne version : exporte ta liste avant (onglet Réglages →
> Exporter), au cas où. L'ancien format de liste est converti automatiquement.

## Sur la télé

**Menu principal**
- **Surprise !** ou une catégorie → tirage au hasard (animation façon roue + son).
- **Droite** ou **✱** sur une catégorie → la liste complète de cette catégorie.
- **Filtres** → genre, durée max, époque, favoris seulement, inclure les déjà vus.
- **Qui choisit ce soir ?** → tire au sort un prénom parmi les joueurs.
- **Historique des tirages**, **Statistiques**, **Paramètres**.
- À droite : résumé des filtres, du mode, des compteurs et du dernier tirage.

**Fiche d'un titre** (après un tirage ou depuis une liste)
- Affiche, année, genres, durée, note publique, saisons/épisodes, résumé.
- Boutons (Gauche/Droite + OK) : **Relancer**, **Marquer vu**, **Favori**, **Noter** (1 à 5).
- **✱** = marquer vu, **Lecture** = relancer, **Retour** = revenir.

**Mode « 3 choix »** (Paramètres) : l'app propose 3 titres côte à côte, tu choisis.

**Liste d'une catégorie** : cases cochées = déjà vus. **OK** ouvre la fiche,
**Lecture** coche/décoche « vu », **✱** change le tri (ajout, A-Z, année, ma note).

**Règles du tirage**
- Les titres déjà vus ne sortent plus (sauf si le filtre « inclure les vus » est activé).
- Les **favoris** ont plus de chances de sortir (x2 par défaut, réglable).
- L'app évite de retomber sur les **derniers titres tirés** (5 par défaut, réglable).

**Paramètres** : mode de tirage, animation (normale / rapide / aucune), anti-répétition,
chances des favoris, résumé affiché ou non, sons, couleur de l'app (6 au choix),
tri des listes, boutique iTunes utilisée, effacer l'historique.

## Sur la page web

L'adresse est affichée en bas de l'écran de la télé, par exemple `http://192.168.1.42:8888`.
Tout s'enregistre automatiquement et la télé se met à jour tout de suite (et inversement).

- **🔍 Rechercher** : Film / Série / Animé, tape un nom, **+ Ajouter**. L'affiche,
  l'année, les genres et la durée sont ajoutés automatiquement. Clique sur une affiche
  pour lire le résumé (et « Ajouter comme déjà vu »). Doublons détectés.
  Sources sans compte ni clé : iTunes (films), TVmaze (séries), MyAnimeList via Jikan (animés).
- **📋 Mes listes** : recherche, filtres (à voir / vus / favoris / genre), tri ;
  étoiles, ♥ favori, case « Vu », retirer ; clic sur un titre → fiche avec résumé,
  **Afficher sur la télé**, déplacer vers une autre catégorie.
  Par catégorie : 📺 tirer sur la télé, renommer, réordonner, **ajouter plusieurs
  titres d'un coup** (un par ligne), tout remettre « à voir », supprimer les vus.
- **🎲 Tirage** : tirer ici (dans le navigateur) ou **sur la télé**, avec les mêmes
  filtres ; « Qui choisit ce soir ? » ; statistiques ; historique des tirages.
- **⚙️ Réglages** : tous les paramètres de la télé, couleur, prénoms des joueurs,
  mémoire utilisée, **Exporter / Importer** (sauvegarde), réglages par défaut, tout effacer.

## Les affiches

- Un titre ajouté avec l'onglet **Rechercher** a automatiquement son affiche et son résumé.
- Un titre ajouté **à la main** (ou les titres d'exemple) n'en a pas : dans **Mes listes**,
  clique sur **🖼️ Trouver les affiches** (le bandeau apparaît s'il en manque). L'app cherche
  dans les films, séries ou animés selon le nom de la catégorie.
- Mauvais film trouvé ? Ouvre le titre → **🖼️ Changer l'affiche** et choisis le bon.
- Sur la télé, l'affiche est chargée depuis Internet au moment de l'afficher : il faut
  que la Roku soit connectée à Internet.

## Limites à connaître

- La page web ne marche **que pendant que l'app est ouverte** sur la télé.
- La mémoire d'une app Roku est petite (~16 Ko pour tout) : environ **150 à 200 titres**.
  La page affiche le pourcentage utilisé. Les films ne gardent que leur numéro iTunes
  (l'affiche est retrouvée à l'affichage) pour économiser de la place.
- Les résumés viennent des bases publiques : souvent **en anglais**. Pour les films,
  choisis la boutique iTunes « France » dans les paramètres pour avoir des titres
  et résumés en français.
- La liste est effacée si l'app est désinstallée ou remplacée par une autre app de
  développement → **Exporter** de temps en temps.

## Développement

```sh
./package.sh             # -> dist/what2watch.zip
python3 make_images.py   # (optionnel) régénère icônes/splash, nécessite Pillow
```

L'app a été testée dans le simulateur [brs-engine](https://github.com/lvcabral/brs-engine)
(`npx brs-cli dist/what2watch.zip -e` puis télécommande simulée via ECP sur le port 8060,
page web sur le port 8888).

### Structure

- `manifest` – infos de l'app
- `source/main.brs` – point d'entrée
- `components/MainScene.xml` – tous les écrans
- `components/MainScene.brs` – navigation, menu, télécommande, synchro avec la page web
- `components/scene/Pick.brs` – tirage (filtres, favoris, anti-répétition, 3 choix, joueurs)
- `components/scene/Screens.brs` – fiche, liste, filtres/paramètres, historique, stats
- `components/Data.brs` – format de la liste, réglages, filtres, genres, registre
- `components/DetailsTask.*` – récupère affiche/résumé/note sur Internet
- `components/WebServerTask.*` – mini serveur HTTP (port 8888) + API
- `web/index.html` – la page web
- `fonts/` – police Inter (licence SIL OFL), `sounds/` – petits sons

### API de la page web

| Méthode | Chemin | Rôle |
|---|---|---|
| GET | `/api/state` | liste + réglages + historique + infos |
| POST | `/api/data` | remplace la liste |
| POST | `/api/settings` | met à jour des réglages (partiel accepté) |
| POST | `/api/cmd` | `{action:"pick",k}`, `{action:"show",c,i}`, `{action:"players"}`, `{action:"clearHistory"}`, `{action:"addHistory",t,c}` |
