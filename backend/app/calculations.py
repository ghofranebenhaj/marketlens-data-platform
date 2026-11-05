from dataclasses import dataclass
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
import numpy as np
from . import config as c


@dataclass(frozen=True)
class Point:
    day: date
    close: Decimal


def indicators(points):
    points = points[-c.WINDOW:]
    # Seuls les rapports sans unité passent par NumPy ; les prix restent Decimal.
    ratios = np.array([float(b.close / a.close - 1) for a, b in zip(points, points[1:])])
    def result(value, method, period, subset, minimum):
        return {'status': 'ok' if len(points) >= minimum else 'historique insuffisant',
                'value': value if len(points) >= minimum else None,
                'method': method, 'period_sessions': period,
                'start': subset[0].day.isoformat() if subset else None,
                'end': subset[-1].day.isoformat() if subset else None,
                'required_points': minimum, 'available_points': len(points)}
    out = {}
    for n in (5, 20):
        value = float(points[-1].close / points[-n-1].close - 1) if len(points) > n else None
        out[f'return_{n}'] = result(value, f'C_fin / C_{n}_séances_avant - 1', n, points[-n-1:], n+1)
    for n in (20, 50):
        value = str(sum((p.close for p in points[-n:]), Decimal(0)) / n) if len(points) > n else None
        out[f'sma_{n}'] = result(value, f'somme des {n} dernières clôtures USD / {n}', n, points[-n:], n+1)
    vol = float(np.std(ratios, ddof=1) * np.sqrt(c.ANNUAL_SESSIONS)) if len(ratios) >= 2 else None
    out['volatility'] = result(vol, 'écart-type échantillon (C_t/C_t-1 - 1), ddof=1 × √252', max(len(points)-1, 0), points, 3)
    peak, dd = Decimal(0), Decimal(0)
    for p in points:
        peak = max(peak, p.close)
        dd = min(dd, p.close / peak - 1)
    out['drawdown'] = result(float(dd), 'min(C_t / max(C_0…C_t) - 1)', max(len(points)-1, 0), points, 2)
    return out


def signal(points):
    data = indicators(points)
    formula = c.SIGNAL_FORMULA
    base = {'label': 'Signal pédagogique', 'formula': formula, 'indicators': data}
    if any(data[k]['value'] is None for k in ('return_20', 'sma_50', 'volatility', 'drawdown')):
        return dict(base, status='historique insuffisant', score=None, classification=None, conditions=[])
    tests = [('rendement20 > 0', data['return_20']['value'] > 0, c.POSITIVE_WEIGHT),
             ('clôture > SMA50', points[-1].close > Decimal(data['sma_50']['value']), c.POSITIVE_WEIGHT),
             ('volatilité > 40 %', data['volatility']['value'] > c.VOLATILITY_LIMIT, c.RISK_WEIGHT),
             ('drawdown < −15 %', data['drawdown']['value'] < c.DRAWDOWN_LIMIT, c.RISK_WEIGHT)]
    score = sum(weight for _, met, weight in tests if met)
    return dict(base, status='ok', score=score,
                classification='favorable' if score >= c.FAVORABLE_SCORE else 'prudence' if score <= c.CAUTION_SCORE else 'neutre',
                conditions=[{'condition': name, 'met': met, 'contribution': weight if met else 0} for name, met, weight in tests])


def scenario(points, quantity, sessions):
    if not 1 <= quantity <= 1000000 or not 1 <= sessions < c.WINDOW:
        raise ValueError('Quantité ou nombre de séances invalide.')
    if len(points) <= sessions:
        return {'status': 'historique insuffisant', 'required_points': sessions+1, 'available_points': len(points)}
    first, last = points[-sessions-1], points[-1]
    def cents(value):
        return int((value * 100).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
    initial, final = first.close * quantity, last.close * quantity
    return {'status': 'ok', 'quantity': quantity, 'sessions': sessions, 'start': str(first.day), 'end': str(last.day),
            'start_price_usd': str(first.close), 'end_price_usd': str(last.close),
            'initial_cents': cents(initial), 'final_cents': cents(final), 'gain_cents': cents(final-initial),
            'return_percent': str((final / initial - 1) * 100), 'currency': 'USD',
            'method': 'quantité × clôture ; gain = valeur finale − valeur initiale ; sans frais ni dividendes'}
