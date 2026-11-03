# Film au Hasard (app Roku)

Choisis une catégorie (Films, Séries, Animés… ou « Surprise ! » pour tout mélanger)
et l'app tire un titre au hasard dans **ta** liste. La liste se modifie depuis
n'importe quel téléphone/PC du même Wi-Fi via une page web servie par la Roku.

## Installation (mode développeur)

1. **Activer le mode développeur** : avec la télécommande, tape
   `Accueil ×3, Haut ×2, Droite, Gauche, Droite, Gauche, Droite`.
   Note l'adresse IP affichée, accepte, choisis un mot de passe (la Roku redémarre).
2. Sur ton PC, ouvre `http://IP-DE-LA-ROKU` (utilisateur : `rokudev`, mot de passe : celui choisi).
3. Clique **Upload**, choisis `dist/film-au-hasard.zip`, puis **Install with zip**.
4. L'app se lance et apparaît dans la liste des chaînes (« Film au Hasard », tout à la fin).

## Utilisation (télécommande)

- **Haut/Bas + OK** : choisir une catégorie → tirage animé, avec l'affiche du titre.
- Sur le résultat : **OK** relancer · **✱** marquer comme vu · **Retour** catégories.
- Sur le menu : **Droite** (ou **✱**) ouvre la liste de la catégorie ;
  **OK** coche/décoche « vu ». Les titres vus ne sortent plus au hasard.
- Pas deux fois le même titre de suite.

## Modifier la liste

En bas de l'écran, l'app affiche une adresse du genre `http://192.168.1.42:8888`.
Ouvre-la sur ton téléphone/PC (même Wi-Fi). Tout s'enregistre automatiquement.
- **Rechercher** : choisis Film / Série / Animé, tape un nom, clique **+ Ajouter**
  (affiche et année incluses). Sources : iTunes (films), TVmaze (séries),
  MyAnimeList via Jikan (animés). Pas besoin de compte ni de clé.
- **Mes listes** : cocher « Vu », retirer un titre, ajouter un titre à la main,
  renommer/réordonner/supprimer des catégories, **Exporter / Importer** (sauvegarde).
- La page se resynchronise toute seule si tu coches des titres avec la télécommande.

⚠️ La page ne marche **que pendant que l'app est ouverte** sur la télé.
La liste est stockée dans la mémoire de la Roku (limite ~15 Ko ≈ 150–250 titres avec affiches, la page affiche le % utilisé).
Elle est effacée si tu désinstalles l'app ou installes une autre app de développement
par-dessus → utilise **Exporter** pour la sauvegarder.

## Rebâtir le zip

```sh
./package.sh          # -> dist/film-au-hasard.zip
python3 make_images.py   # (optionnel) régénère icônes/splash, nécessite Pillow
```

## Structure

- `manifest` – infos de l'app
- `source/main.brs` – point d'entrée
- `components/MainScene.*` – écrans (catégories + tirage)
- `components/WebServerTask.*` – mini serveur HTTP (port 8888)
- `components/Data.brs` – lecture/écriture/validation de la liste
- `web/index.html` – page d'édition
