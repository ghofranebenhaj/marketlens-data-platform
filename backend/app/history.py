import asyncio
from datetime import datetime, date, timezone
from decimal import Decimal, InvalidOperation
import httpx
from . import config as c
from .calculations import Point


class Unavailable(Exception):
    pass


class History:
    def __init__(self, settings, transport=None, clock=None, sleep=asyncio.sleep):
        self.settings, self.transport = settings, transport
        self.clock = clock or (lambda: datetime.now(timezone.utc))
        self.sleep, self.cache = sleep, {}
        self.locks = {symbol: asyncio.Lock() for symbol in c.SYMBOLS}

    async def get(self, symbol):
        if symbol not in c.SYMBOLS:
            raise ValueError('Symbole inconnu du catalogue.')
        if not self.settings.twelve_key:
            raise Unavailable('Assistant indisponible : clé Twelve Data absente.')
        async with self.locks[symbol]:
            cached = self.cache.get(symbol)
            now = self.clock()
            if cached and 0 <= (now - cached[0]).total_seconds() < c.CACHE_SECONDS:
                return cached[1], self.source(symbol, cached[0], cached[1], True)
            async with httpx.AsyncClient(timeout=c.REQUEST_TIMEOUT, transport=self.transport) as client:
                for attempt in range(c.RETRIES+1):
                    try:
                        response = await client.get('https://api.twelvedata.com/time_series', params={
                            'symbol': symbol, 'interval': '1day', 'outputsize': c.WINDOW,
                            'apikey': self.settings.twelve_key, 'order': 'ASC', 'format': 'JSON'})
                        if response.status_code == 429 or response.status_code >= 500:
                            raise Unavailable('Fournisseur indisponible ou quota atteint.')
                        if response.status_code != 200:
                            raise ValueError('Erreur HTTP du fournisseur.')
                        payload = response.json()
                        if not isinstance(payload, dict):
                            raise ValueError('Réponse inattendue.')
                        if payload.get('status') == 'error':
                            if str(payload.get('code')) in ('429', '500', '502', '503'):
                                raise Unavailable('Fournisseur indisponible ou quota atteint.')
                            raise ValueError('Historique refusé par le fournisseur.')
                        meta = payload.get('meta')
                        if not isinstance(meta, dict) or meta.get('symbol') != symbol or meta.get('currency') != 'USD':
                            raise ValueError('Provenance ou devise inattendue.')
                        rows = payload.get('values')
                        if not isinstance(rows, list) or not rows:
                            raise ValueError('Historique vide.')
                        points = sorted([Point(date.fromisoformat(row['datetime']), Decimal(row['close'])) for row in rows], key=lambda p: p.day)
                        if any(not p.close.is_finite() or p.close <= 0 or p.day > now.date() for p in points):
                            raise ValueError('Historique invalide.')
                        if len({p.day for p in points}) != len(points):
                            raise ValueError('Dates dupliquées.')
                        # Exclure la séance du jour, dont la clôture pourrait être provisoire.
                        points = [p for p in points if p.day < now.date()][-c.WINDOW:]
                        if not points:
                            raise ValueError('Historique terminé absent.')
                        fetched = self.clock()
                        self.cache[symbol] = (fetched, points)
                        return points, self.source(symbol, fetched, points, False)
                    except (httpx.RequestError, Unavailable):
                        if attempt == c.RETRIES:
                            raise Unavailable('Assistant indisponible : historique inaccessible ou quota atteint.') from None
                        await self.sleep(0.5 * 2**attempt)
                    except (ValueError, KeyError, TypeError, InvalidOperation):
                        raise Unavailable('Assistant indisponible : historique vide, refusé ou invalide.') from None

    @staticmethod
    def source(symbol, fetched, points, cached):
        return {'provider': 'Twelve Data', 'symbol': symbol, 'interval': '1day',
                'start': str(points[0].day), 'end': str(points[-1].day),
                'fetched_at': fetched.isoformat(), 'cached': cached,
                'label': f'donnée en cache du {fetched.isoformat()}' if cached else 'Clôtures journalières datées, différées',
                'url': 'https://twelvedata.com/docs/market-data/time-series'}
