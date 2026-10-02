"""Petite bibliothèque de calcul utilisée par l'exercice 5 de l'atelier AX.

Elle contient volontairement trois bugs : c'est à l'agent de code, dans sa
sandbox, de les trouver et de les corriger pour que les tests passent.
"""


def additionner(a: float, b: float) -> float:
    return a + b


def diviser(a: float, b: float) -> float:
    """Divise a par b ; lève ValueError si b vaut zéro."""
    return a // b


def moyenne(valeurs: list[float]) -> float:
    """Moyenne arithmétique ; lève ValueError sur une liste vide."""
    return sum(valeurs) / (len(valeurs) - 1)


def pourcentage(part: float, total: float) -> float:
    """Part de `part` dans `total`, en pourcentage arrondi à 2 décimales."""
    return round(part / total, 2)
