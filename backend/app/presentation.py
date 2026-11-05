"""Présentation française et contrôle des nombres, sans modifier les données métier."""
import re
from decimal import Decimal, ROUND_HALF_UP
from . import config as c
from .knowledge import normalize

LABELS = {
    'return_5': 'Rendement sur 5 séances', 'return_20': 'Rendement sur 20 séances',
    'volatility': 'Volatilité historique annualisée', 'drawdown': 'Baisse maximale depuis un sommet',
    'sma_20': 'Moyenne mobile sur 20 séances', 'sma_50': 'Moyenne mobile sur 50 séances',
}


def decimal_fr(value):
    rounded = Decimal(str(value)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    if rounded == 0:
        rounded = abs(rounded)
    return format(rounded, '.2f').replace('.', ',')


def percent(value):
    return decimal_fr(Decimal(str(value)) * 100) + ' %'


def explanations(kind, data, passages):
    if kind == 'glossary':
        return [p['text'] for p in passages]
    if kind == 'scenario':
        if data['status'] != 'ok':
            return ['Historique insuffisant pour ce scénario.']
        return [f"Scénario historique sans frais pour {data['quantity']} actions sur {data['sessions']} séances, du {data['start']} au {data['end']}.",
                f"Clôture initiale : {decimal_fr(data['start_price_usd'])} USD ; clôture finale : {decimal_fr(data['end_price_usd'])} USD.",
                f"Valeur initiale : {decimal_fr(Decimal(data['initial_cents'])/100)} USD ; valeur finale : {decimal_fr(Decimal(data['final_cents'])/100)} USD.",
                f"Gain ou perte : {decimal_fr(Decimal(data['gain_cents'])/100)} USD ; rendement : {decimal_fr(data['return_percent'])} %.",
                'Ce résultat rétrospectif exclut les frais et ne prédit aucun résultat futur.']
    values = data['indicators']
    sentences = []
    for name, item in values.items():
        label = LABELS[name]
        if item['value'] is None:
            sentences.append(f'{label} : historique insuffisant.')
        else:
            value = decimal_fr(item['value'])+' USD' if name.startswith('sma') else percent(item['value'])
            sentences.append(f"{label} : {value}, du {item['start']} au {item['end']} ; période : {item['period_sessions']} séances ; méthode : {item['method']}.")
    educational = data if kind == 'signal' else data['signal']
    if educational['score'] is None:
        sentences.append('Signal pédagogique : historique insuffisant, aucun score calculé.')
    else:
        sentences.append(f"Signal pédagogique : {educational['classification']} ; score : {educational['score']}.")
    conditions = [
        'Rendement sur 20 séances positif',
        'Dernière clôture supérieure à la moyenne mobile sur 50 séances',
        f'Volatilité annualisée supérieure à {percent(c.VOLATILITY_LIMIT)}',
        f'Baisse maximale inférieure à {percent(c.DRAWDOWN_LIMIT)}',
    ]
    for label, condition in zip(conditions, educational['conditions']):
        sentences.append(f"{label} : {'condition remplie' if condition['met'] else 'condition non remplie'} ; contribution au score : {condition['contribution']}.")
    sentences.append(f"Formule du signal : {c.POSITIVE_WEIGHT:+d} si le rendement sur 20 séances est positif, {c.POSITIVE_WEIGHT:+d} si la clôture dépasse la moyenne mobile sur 50 séances, {c.RISK_WEIGHT} si la volatilité dépasse {percent(c.VOLATILITY_LIMIT)}, {c.RISK_WEIGHT} si la baisse maximale est inférieure à {percent(c.DRAWDOWN_LIMIT)} ; favorable à partir de {c.FAVORABLE_SCORE}, prudence jusqu’à {c.CAUTION_SCORE}, neutre sinon.")
    return sentences


# Dates et quantités signées sont des jetons entiers : pas de validation par sous-chaîne.
# Le suffixe % fait partie du jeton pour éviter une confusion ratio/pourcentage.
NUMBER = re.compile(r'\d{4}-\d{2}-\d{2}|[+\-−]?\d+(?:[.,]\d+)?(?:[eE][+\-]?\d+)?(?:\s*%)?')


def numbers(text):
    return {re.sub(r'\s+', '', match.group()).replace('−', '-').replace('.', ',')
            for match in NUMBER.finditer(text)}


def valid_explanation(text, supplied):
    if not isinstance(text, str) or not text.strip() or len(text) > 6000:
        return False
    # Une ponctuation décimale n'est pas une fin de phrase.
    sentences = [s for s in re.split(r'(?<!\d)[.!?]+\s*|(?<=\d)[.!?]+(?=\s|$)', text.strip()) if s.strip()]
    if not 5 <= len(sentences) <= 8 or not numbers(text) <= numbers('\n'.join(supplied)):
        return False
    q = normalize(text)
    if re.search(r'\b(achete\w*|vend\w*|investis\w*)\b|va (monter|baisser)|sera a|prix actuel|cours actuel', q):
        return False
    # Les nombres doivent être repris en chiffres, comme les valeurs fournies.
    if re.search(r'\b(zero|deux|trois|quatre|cinq|six|sept|huit|neuf|dix|onze|douze|treize|quatorze|quinze|seize|vingt|trente|quarante|cinquante|soixante|cent|cents|mille|million\w*|milliard\w*)\b', q):
        return False
    return not any(key in text for key in LABELS)


def failure_reason(exc):
    # Ne jamais publier str(exc), qui peut contenir une URL, une clé ou le prompt.
    code = getattr(exc, 'code', None) or getattr(exc, 'status_code', None)
    response = getattr(exc, 'response', None)
    code = code or getattr(response, 'status_code', None)
    if str(code) == '429':
        return 'quota du modèle atteint'
    if str(code) in ('401', '403'):
        return 'clé du modèle refusée ou accès non autorisé'
    if isinstance(exc, TimeoutError):
        return 'modèle indisponible (délai dépassé)'
    return 'modèle indisponible'
