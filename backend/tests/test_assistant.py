import asyncio
import json
from datetime import date, timedelta, datetime, timezone
from decimal import Decimal
import httpx
import numpy as np
import pytest
from fastapi.testclient import TestClient
from app.calculations import Point, indicators, signal, scenario
from app.config import Settings, DISCLAIMER, SYMBOLS
from app.history import History, Unavailable
from app.main import create_app
from app.knowledge import Corpus
from app.chat import route


def series(values):
    return [Point(date(2025, 1, 1)+timedelta(days=i), Decimal(str(v))) for i, v in enumerate(values)]


class FakeHistory:
    def __init__(self, points=None):
        self.points = points if points is not None else series(range(100, 160))
        self.calls = 0

    async def get(self, symbol):
        self.calls += 1
        return self.points, {'provider': 'Twelve Data', 'symbol': symbol, 'interval': '1day',
                             'start': str(self.points[0].day), 'end': str(self.points[-1].day)}


class FakeModel:
    def __init__(self, output=None, fail=False):
        self.output, self.fail, self.calls = output, fail, 0

    async def explain(self, settings, sentences, data, passages):
        self.calls += 1
        if self.fail:
            raise TimeoutError()
        if self.output is not None:
            return self.output
        # Texte libre simulé : indicateurs, signal et conditions en six phrases.
        return ' '.join(sentences[:4] + [sentences[6], '; '.join(s.rstrip('.') for s in sentences[7:11])+'.'])


def client(settings=None, history=None, model=None):
    return TestClient(create_app(settings or Settings(), history or FakeHistory(), model))


def test_constant():
    out = indicators(series([100]*60))
    assert out['volatility']['value'] == 0
    assert out['drawdown']['value'] == 0
    assert out['return_20']['value'] == 0
    assert Decimal(out['sma_50']['value']) == 100
    assert signal(series([100]*60))['classification'] == 'neutre'


def test_linear_and_sample_volatility():
    out = indicators(series(range(100, 160)))
    assert out['return_5']['value'] == pytest.approx(159/154-1)
    assert out['return_20']['value'] == pytest.approx(159/139-1)
    assert Decimal(out['sma_20']['value']) == Decimal('149.5')
    assert Decimal(out['sma_50']['value']) == Decimal('134.5')
    expected = np.std([b/a-1 for a, b in zip(range(100, 159), range(101, 160))], ddof=1)*np.sqrt(252)
    assert out['volatility']['value'] == pytest.approx(expected)


def test_drawdown():
    assert indicators(series([100, 120, 90, 110]))['drawdown']['value'] == -.25


@pytest.mark.parametrize('count', [0, 1, 2, 5, 20, 50])
def test_insufficient(count):
    data = indicators(series([100]*count))
    assert data['sma_50']['value'] is None
    assert data['sma_50']['status'] == 'historique insuffisant'
    assert signal(series([100]*count))['score'] is None


def test_signal_manual():
    favorable = signal(series(range(100, 160)))
    assert favorable['score'] == 2
    assert favorable['classification'] == 'favorable'
    risk = signal(series([100]*59+[50]))
    assert risk['score'] == -2
    assert risk['classification'] == 'prudence'
    assert 'achète' not in json.dumps(favorable, ensure_ascii=False).lower()
    assert 'vends' not in json.dumps(risk, ensure_ascii=False).lower()


def test_scenario_manual_decimal():
    data = scenario(series(['10.10', '12.12']), 3, 1)
    assert (data['initial_cents'], data['final_cents'], data['gain_cents']) == (3030, 3636, 606)
    assert Decimal(data['return_percent']) == 20
    assert scenario(series([100]), 3, 1)['status'] == 'historique insuffisant'


@pytest.mark.parametrize('quantity,sessions', [(0, 1), (-1, 1), (1, 0), (1, 100), (1000001, 1)])
def test_invalid_scenario(quantity, sessions):
    with pytest.raises(ValueError):
        scenario(series([100, 110]), quantity, sessions)
    assert client().get(f'/assets/AAPL/scenario?quantity={quantity}&sessions={sessions}').status_code == 422


@pytest.mark.parametrize('question,target', [
    ('Quel est le prix actuel AAPL ?', 'Marchés'), ('Quel est mon solde ?', 'Portefeuille'),
    ('Mes positions AAPL ?', 'Portefeuille'), ('AAPL va monter ?', 'prédiction'),
    ('AAPL sera à combien demain ?', 'prédiction'), ('Dois-je acheter AAPL ?', 'conseil'),
    ('Vends-moi AAPL', 'conseil')])
def test_refusals(question, target):
    history, model = FakeHistory(), FakeModel()
    response = client(Settings(gemini_key='fake'), history, model).post('/chat', json={'question': question})
    assert response.status_code == 200
    data = response.json()
    assert target in data['answer']
    assert data['disclaimer'] == DISCLAIMER
    assert history.calls == model.calls == 0
    assert data['sources'] == []


def test_validation_and_unknown():
    c = client()
    assert c.post('/chat', json={'question': 'x'*501}).status_code == 422
    assert c.post('/chat', json={'question': ' '}).status_code == 422
    assert c.get('/assets/IBM/indicators').status_code == 404
    assert 'Précisez' in c.post('/chat', json={'question': 'Analyse IBM'}).json()['answer']
    assert 'Précisez' in c.post('/chat', json={'question': 'Analyse AAPL MSFT'}).json()['answer']


def test_chat_scenario_and_signal():
    c = client()
    data = c.post('/chat', json={'question': 'Et si 3 actions AAPL il y a 5 séances ?'}).json()
    assert data['data']['gain_cents'] == 1500
    assert data['generated_by'] == 'template'
    assert data['answer'].startswith('Réponse par gabarit')
    data = c.post('/chat', json={'question': 'Signal AAPL'}).json()
    assert data['data']['score'] == 2
    assert not any(word in data['answer'].lower() for word in ['achète', 'vends'])
    assert data['sources'][-1]['provider'] == 'Twelve Data'


def test_llm_success_and_fallback():
    settings = Settings(gemini_key='fake')
    data = client(settings, model=FakeModel()).post('/chat', json={'question': 'Analyse AAPL'}).json()
    assert data['generated_by'] == 'llm'
    for model in [FakeModel(fail=True), FakeModel(output=[999]), FakeModel(output=['achète à 999 USD'])]:
        data = client(settings, model=model).post('/chat', json={'question': 'Analyse AAPL'}).json()
        assert data['generated_by'] == 'template'
        assert '999 USD' not in data['answer']
    for settings in [Settings(require_llm=True), Settings(gemini_key='fake', require_llm=True)]:
        response = client(settings, model=FakeModel(fail=True)).post('/chat', json={'question': 'Analyse AAPL'})
        assert response.status_code == 503


def test_missing_history_key_and_health():
    c = TestClient(create_app(Settings()))
    assert c.get('/health').json()['status'] == 'ok'
    response = c.get('/assets/AAPL/indicators')
    assert response.status_code == 503
    assert 'clé Twelve Data absente' in response.json()['answer']
    assert c.post('/chat', json={'question': 'Qu’est-ce que la volatilité ?'}).json()['generated_by'] == 'template'


def test_corpus_and_catalog():
    corpus = Corpus()
    assert corpus.search('volatilité')[0]['file'] in ('glossaire.md', 'formules.md')
    assert corpus.search('zzzxxyy') == []
    from pathlib import Path
    dart = (Path(__file__).resolve().parents[2]/'lib/core/models.dart').read_text(encoding='utf-8')
    import re
    assert tuple(re.findall(r"Asset\('([A-Z]+)'", dart)) == SYMBOLS


def payload():
    return {'meta': {'symbol': 'AAPL', 'currency': 'USD'}, 'values': [
        {'datetime': '2025-01-01', 'close': '10.10'}, {'datetime': '2025-01-02', 'close': '12.12'}]}


def test_cache_expiry_and_retries():
    async def run():
        now = [datetime(2025, 1, 3, tzinfo=timezone.utc)]
        calls, delays = [], []
        def handler(request):
            calls.append(request)
            return httpx.Response(200, json=payload())
        async def sleep(delay):
            delays.append(delay)
        h = History(Settings(twelve_key='fake'), httpx.MockTransport(handler), lambda: now[0], sleep)
        _, first = await h.get('AAPL')
        _, second = await h.get('AAPL')
        assert not first['cached'] and second['cached']
        assert 'donnée en cache du' in second['label']
        assert len(calls) == 1
        now[0] += timedelta(hours=13)
        await h.get('AAPL')
        assert len(calls) == 2
        h.transport = httpx.MockTransport(lambda request: httpx.Response(429))
        now[0] += timedelta(hours=13)
        with pytest.raises(Unavailable):
            await h.get('AAPL')
        assert delays == [0.5, 1.0]
    asyncio.run(run())


@pytest.mark.parametrize('body', [[], {'meta': None}, {}, {'values': []}, {'status': 'error', 'code': 400},
                                  {'meta': {'symbol': 'AAPL', 'currency': 'EUR'}, 'values': [1]}])
def test_bad_history(body):
    async def run():
        h = History(Settings(twelve_key='fake'), httpx.MockTransport(lambda request: httpx.Response(200, json=body)))
        with pytest.raises(Unavailable):
            await h.get('AAPL')
        assert not h.cache
    asyncio.run(run())


@pytest.mark.parametrize('mode', ['timeout', 'http500', 'quota_json', 'duplicates', 'nan', 'empty', 'malformed'])
def test_transport_failures(mode):
    async def run():
        calls, delays = [], []
        def handler(request):
            calls.append(1)
            if mode == 'timeout':
                raise httpx.ReadTimeout('timeout', request=request)
            if mode == 'http500':
                return httpx.Response(500)
            if mode == 'quota_json':
                return httpx.Response(200, json={'status': 'error', 'code': 429})
            if mode == 'malformed':
                return httpx.Response(200, text='not json')
            data = payload()
            if mode == 'duplicates':
                data['values'][1]['datetime'] = data['values'][0]['datetime']
            elif mode == 'nan':
                data['values'][0]['close'] = 'NaN'
            elif mode == 'empty':
                data['values'] = []
            return httpx.Response(200, json=data)
        async def sleep(delay):
            delays.append(delay)
        h = History(Settings(twelve_key='fake'), httpx.MockTransport(handler), sleep=sleep)
        with pytest.raises(Unavailable):
            await h.get('AAPL')
        assert len(calls) == (3 if mode in ('timeout', 'http500', 'quota_json') else 1)
        assert not h.cache
    asyncio.run(run())


def test_ambiguous_and_unsupported_questions():
    for question in ['Analyse', 'Et si 2 actions AAPL ?', 'Analyse AAPL MSFT', 'Et si 1.5 actions AAPL il y a 5 séances ?']:
        assert route(question)[0] == 'clarify'
    data = client().post('/chat', json={'question': 'Explique zzzxxyy'}).json()
    assert 'documentation ne permet pas' in data['answer']


def test_insufficient_endpoint_and_dated_metadata():
    c = client(history=FakeHistory(series([100]*10)))
    result = c.get('/assets/AAPL/signal').json()
    assert result['data']['score'] is None
    data = c.get('/assets/AAPL/indicators').json()['data']
    assert data['return_5']['start'] == '2025-01-05'
    assert data['return_5']['end'] == '2025-01-10'
    assert data['return_5']['period_sessions'] == 5


def test_sdk_configuration_without_network():
    from google import genai
    from google.genai import types
    cfg = types.GenerateContentConfig(response_mime_type='application/json', response_schema=list[int], temperature=0)
    with genai.Client(api_key='not-a-real-key', http_options=types.HttpOptions(timeout=15000)) as sdk:
        assert sdk.models is not None
        assert cfg.response_schema == list[int]
