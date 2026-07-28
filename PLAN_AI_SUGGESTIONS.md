# Plan : Suggestions IA de commentaires — Afrolook

**Date :** 2026-07-24  
**Branche :** `refonte_claude`  
**Auteur initial :** Claude Sonnet 4.6

---

## Objectif

Remplacer les suggestions de commentaires statiques (`_allSuggestions` shuffle) par des suggestions générées dynamiquement via une architecture à 2 niveaux :

- **Tier 2 :** ML Kit Smart Reply (`google_mlkit_smart_reply`) — on-device, ~100ms, 0 MB ajouté à l'app
- **Tier 3 :** Templates par thème (détection par mots-clés dans la description du post) — fallback universel, <1ms

---

## État actuel

### ✅ TERMINÉ — `postWidgetPage.dart`

**Package ajouté** dans `pubspec.yaml` :
```yaml
google_mlkit_smart_reply: ^0.10.0
```
(résolu en `0.10.1`)

**Service créé** : `lib/services/comment_suggestion_service.dart`
- Cache LRU par `postId` (max 50 entrées)
- ML Kit Smart Reply pour les suggestions contextuelles
- 10 thèmes de templates : musique, mode, cuisine, sport, voyage, art, mariage, bébé, business, motivation
- Méthode `CommentSuggestionService.getSuggestions(postId, description)` → `Future<List<String>>`
- Méthode `CommentSuggestionService.invalidate(postId)` — à appeler après envoi d'un commentaire

**Modifications dans `postWidgetPage.dart`** :
- Supprimé : `static const _allSuggestions = [...]` (ligne ~143)
- Supprimé : `_previewSuggestions = (List.of(_allSuggestions)..shuffle(...)).take(6)...` dans `initState`
- Ajouté : `bool _isSuggestionsLoading = false`
- Ajouté : import `comment_suggestion_service.dart`
- Ajouté : méthode `_loadSuggestions()` qui appelle le service de manière async
- Modifié : `_buildCommentPreview` — affiche des chips skeleton pendant le chargement (`_isSuggestionsLoading`)

---

## Pages restantes — même pattern à appliquer

Les 3 pages suivantes utilisent aussi des suggestions statiques similaires. Appliquer exactement le même pattern que `postWidgetPage.dart` :

### 1. `lib/pages/postDetails.dart` (DetailsPost)
**À chercher :** une liste statique de suggestions ou `_previewSuggestions`  
**À faire :**
1. Ajouter `import '../../../services/comment_suggestion_service.dart';` (ajuster chemin)
2. Supprimer la liste statique
3. Ajouter `bool _isSuggestionsLoading = false;`
4. Ajouter méthode `_loadSuggestions()` identique
5. Appeler `_loadSuggestions()` dans `initState()`
6. Mettre à jour le widget de suggestions pour afficher skeleton pendant chargement

### 2. `lib/pages/postDetailsVideo.dart` (VideoYoutubePageDetails)
Même pattern.

### 3. `lib/pages/post_video_format_tel_details.dart` (PostDetailsVideoFormatTel)
Même pattern.

---

## Comment appliquer sur chaque page — template de code

### Dans `initState()` :
```dart
// Remplacer le shuffle statique par :
_loadSuggestions();
```

### Méthode à ajouter (identique partout) :
```dart
Future<void> _loadSuggestions() async {
  if (!mounted) return;
  final postId = widget.post.id;           // adapter le nom du paramètre selon la page
  final description = widget.post.description ?? '';
  if (postId == null || description.isEmpty) return;

  setState(() => _isSuggestionsLoading = true);
  try {
    final suggestions = await CommentSuggestionService.getSuggestions(
      postId,
      description,
    );
    if (!mounted) return;
    setState(() {
      _previewSuggestions = suggestions;
      _isSuggestionsLoading = false;
    });
  } catch (_) {
    if (!mounted) return;
    setState(() => _isSuggestionsLoading = false);
  }
}
```

### Widget de suggestions (avec skeleton) :
```dart
SizedBox(
  height: 26,
  child: _isSuggestionsLoading
      ? Row(
          children: List.generate(3, (_) => Container(
            margin: const EdgeInsets.only(right: 6),
            width: 70,
            decoration: BoxDecoration(
              color: colors.shimmerBase,
              borderRadius: BorderRadius.circular(13),
            ),
          )),
        )
      : ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _previewSuggestions.length,
          itemBuilder: (_, i) {
            final text = _previewSuggestions[i];
            return GestureDetector(
              onTap: () => _sendQuickComment(text),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: colors.border.withOpacity(0.6)),
                ),
                child: Center(
                  child: Text(text,
                      style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                ),
              ),
            );
          },
        ),
),
```

### Optionnel — invalider le cache après envoi d'un commentaire :
```dart
// Dans _sendQuickComment() ou équivalent, après envoi réussi :
CommentSuggestionService.invalidate(widget.post.id!);
```

---

## Rappel : contraintes de sécurité immuables

- Commission split : **75% parrain affiché**, **25% revenus app — NE JAMAIS afficher dans l'UI**
- Toujours utiliser `loginUserData` (JAMAIS `userData`) pour les données utilisateur

---

## Vérifications post-implémentation

- [ ] `flutter pub get` → succès
- [ ] `flutter analyze` → aucune nouvelle erreur (les warnings pré-existants sont attendus)
- [ ] Test sur Android physique : les suggestions apparaissent en <2s
- [ ] Test hors-ligne : le Tier 3 (templates) prend le relai, aucun crash
- [ ] Test iOS : comportement identique Android
