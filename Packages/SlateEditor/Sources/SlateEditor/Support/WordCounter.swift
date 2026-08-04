import Foundation

/// Compte de mots derive d'un texte brut. Fonction pure, sans dependance a `SlateModel`
/// (elle prend directement `Note.plainText`, deja calcule par
/// `Note.refreshDerivedText()`) : cet endroit ne recompte jamais lui-meme le contenu
/// des blocs, il se contente de compter les mots du texte derive fourni par l'appelant.
public enum WordCounter {
    /// Nombre de mots dans `text` : suites de caracteres separees par un blanc
    /// (espace, tabulation, retour a la ligne). Une chaine vide ou entierement blanche
    /// compte 0 mot.
    public static func wordCount(in text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }
}
