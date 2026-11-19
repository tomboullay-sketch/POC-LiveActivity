# POC Live Activity avec ActivityKit

Une app minimale qui télécharge un fichier et affiche sa progression dans une Live Activity. La Live Activity montre un titre, le logo de l'app et un anneau de chargement avec un bouton stop au centre.

Le but est de comparer ce qui s'affiche sur un iPhone en iOS 18 et sur un iPhone en iOS 27.

## Builder sur un iPhone

Il faut Xcode 27 et un iPhone en iOS 17 ou plus. Tuist n'est pas nécessaire.

1. Ouvre `POC-LiveActivity.xcodeproj`.
2. Dans `Config.xcconfig`, renseigne ton `DEVELOPMENT_TEAM`, et un `BUNDLE_ID_PREFIX` à toi si `com.example` est refusé. Tu peux aussi choisir ton équipe dans **Signing & Capabilities**, pour les deux cibles.
3. Choisis ton iPhone et lance le schéma `POC-LiveActivity`.

`Project.swift` ne sert qu'à régénérer le projet avec `tuist generate --no-open`.

## Les deux boutons

| Bouton | API utilisée | Ce qu'on attend en iOS 27 |
|---|---|---|
| Télécharger l'image (40 Mo) | `URLSessionDownloadTask` | notre Live Activity seule |
| Télécharger la vidéo (flux HLS) | `AVAssetDownloadTask`, comme le vrai D2Go | notre Live Activity **et** la native d'AVFoundation, sauf si `isDiscretionary` est activé |

L'interrupteur `isDiscretionary` ne concerne que la vidéo. Activé, il coupe la Live Activity native, mais laisse iOS retarder le téléchargement.

Le journal en bas de l'app note les démarrages, les fins, les annulations (et leur origine) et les codes d'erreur.

## Ce qu'il faut tester

1. **iOS 18 et iOS 27, image** : notre Live Activity s'affiche sur l'écran verrouillé, et le bouton stop annule le téléchargement.
2. **iOS 27, vidéo** : voit-on deux Live Activities, la nôtre et la native ?
3. **iOS 27, vidéo avec `isDiscretionary` activé** : la native disparaît-elle, et de combien le téléchargement est-il retardé ?
4. **iOS 27, stop de la native** : le journal doit afficher `NSCocoaErrorDomain 3072`.
5. **App en arrière-plan** : le pourcentage continue-t-il d'avancer ? La ligne « Mis à jour il y a… » montre depuis combien de temps l'app n'a plus mis l'activité à jour.

## Bon à savoir

- **Écran verrouillé seulement.** Sans Dynamic Island (iPhone XR, iPhone 12), la Live Activity n'apparaît que sur l'écran verrouillé et dans le centre de notifications.
- **Téléchargement trop rapide en Wi-Fi.** Pour avoir le temps de tester, active Réglages > Développeur > Network Link Conditioner > 3G.
- **Réglages.** Les Live Activities doivent être autorisées dans Réglages > POC Live Activity.
- **Fermeture forcée.** Fermer l'app depuis le sélecteur d'apps annule ses téléchargements en arrière-plan : c'est iOS qui fait ça.
- **Vidéo et simulateur.** La vidéo ne se télécharge pas sur simulateur.
- **Erreur `-1200` (TLS).** Elle vient d'un proxy réseau qui inspecte le TLS, comme sur le Mac du bureau. Change l'URL dans `App/POCConfig.swift` ou change de réseau.
