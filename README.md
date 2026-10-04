# Projeko

Application HTML statique sur Vercel avec comptes et données Supabase.

## Parcours

- Client : inscription/connexion, projet par métier avec budget, échéancier et photos, soumissions reçues, choix de l’entrepreneur, messages, début et fin des travaux.
- Entrepreneur : inscription et services/territoire, projets correspondants, soumission unique par projet, offres en attente/acceptées/non retenues/terminées, messages et profil.
- Les spécialistes voient les projets du métier choisi. Le service `general` permet de voir tous les métiers, dans le rayon de travail. Les participants conservent l’accès aux projets pour lesquels ils ont envoyé une offre.
- Les coordonnées proviennent des centres des localités GeoNames du Québec. Les distances sont approximatives.

## Architecture

`index.html` conserve les pages et le design approuvés. `app/marketplace.js` branche les actions aux tables Supabase; `app/core.js` définit les métiers et le calcul de distance. Le client SDK 2.117.2 est servi localement. La clé publique du projet est prévue pour le navigateur; les autorisations sont appliquées par RLS.

Les sources SQL dans `database/` correspondent aux migrations appliquées via le connecteur Supabase. `rd_private` contient les fonctions de lookup et les transactions privilégiées; leurs droits sont limités aux comptes authentifiés et chaque opération vérifie le propriétaire ou le participant. Les photos sont privées et accessibles par liens signés.

## Vérification

`npm ci && npm test` vérifie le parcours avec une simulation de Supabase dans JSDOM. `tests/marketplace-rls.sql` vérifie les règles sous le rôle `authenticated`, en transaction annulée; aucun profil ni projet de test ne reste dans la base.

Audit du 3 octobre 2026 : les trois suites SQL (`marketplace-rls`, `security-rls`, `business-rls`) ont été exécutées sur le projet Supabase, avec annulation des fixtures. Les tests UI couvrent également la récupération au démarrage, le nettoyage des données après déconnexion, les routes de modification par rôle, les erreurs de déconnexion et le rendu de textes contenant du HTML. `rd_save_business_changes` applique la présentation et la réalisation dans une même transaction, sous les permissions RLS du compte appelant; un échec ne laisse pas une présentation partiellement modifiée. Archiver un projet clôt ses offres en attente dans la transaction du changement de statut.

Limites : JSDOM simule Auth et le réseau. La réception des courriels de confirmation/récupération et les interactions sur un iPhone physique nécessitent encore des essais réels. L’avis Supabase sur les mots de passe compromis reste présent; cette protection nécessite Supabase Pro ou supérieur.

## Réglages Auth à terminer dans Supabase

Projet : `qefpomgdknlcsavkritc`, organisation Projeko.

- Authentication → URL Configuration : Site URL `https://projeko.vercel.app`; autoriser `https://projeko.vercel.app/**` dans Redirect URLs.
- Garder la confirmation des courriels activée.
- Configurer un service SMTP pour les courriels de confirmation et de récupération destinés aux utilisateurs publics. Le SMTP par défaut Supabase est limité; le parcours public d’inscription ne doit pas être considéré comme vérifié avant cette configuration et un essai de confirmation.

Les notifications push, la vérification réelle des licences RBQ, les pièces jointes du chat et la modification des projets publiés restent des étapes séparées.
