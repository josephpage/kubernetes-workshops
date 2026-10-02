import pytest

from calculatrice import additionner, diviser, moyenne, pourcentage


def test_additionner():
    assert additionner(2, 3) == 5


def test_diviser():
    assert diviser(7, 2) == 3.5


def test_diviser_par_zero():
    with pytest.raises(ValueError):
        diviser(1, 0)


def test_moyenne():
    assert moyenne([2, 4, 6]) == 4


def test_moyenne_vide():
    with pytest.raises(ValueError):
        moyenne([])


def test_pourcentage():
    assert pourcentage(1, 3) == 33.33
