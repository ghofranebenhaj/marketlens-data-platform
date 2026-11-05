import pytest
from app.config import Settings
from app.presentation import percent, valid_explanation
from test_assistant import client, FakeModel, FakeHistory, series


def test_formatted_analysis_keeps_raw_numbers_and_signal():
    result = client(history=FakeHistory(series([100]*59+[95.62]))).post('/chat', json={'question': 'Analyse AAPL'}).json()
    assert 'Rendement sur 5 séances : -4,38 %' in result['answer']
    assert 'return_5' not in result['answer']
    assert result['data']['indicators']['return_5']['value'] == pytest.approx(-.0438)
    assert result['data']['signal']['conditions']
    assert 'Signal pédagogique' in result['answer']
    assert all('provider' in source for source in result['sources'])


def test_valid_free_text_is_accepted():
    model = FakeModel()
    result = client(Settings(gemini_key='fake'), model=model).post('/chat', json={'question': 'Analyse AAPL'}).json()
    assert result['generated_by'] == 'llm'
    assert 'Signal pédagogique' in result['answer']
    assert 'fallback_reason' not in result


@pytest.mark.parametrize('require_llm', [False, True])
def test_invented_number_is_rejected(require_llm):
    class InventingModel(FakeModel):
        async def explain(self, *args):
            text = await super().explain(*args)
            return text.replace('Rendement sur 5 séances', 'Rendement sur 999 séances')
    result = client(Settings(gemini_key='fake', require_llm=require_llm), model=InventingModel()).post('/chat', json={'question': 'Analyse AAPL'}).json()
    assert result['generated_by'] == 'template'
    assert '999' not in result['answer']
    assert 'sortie du modèle rejetée' in result['fallback_reason']


@pytest.mark.parametrize('text', ['Rendement : 4,38 %.', 'Rendement : -4,39 %.', 'Rendement : -4,38.', 'Rendement : 999.', 'Rendement : trois.'])
def test_numeric_control_sign_units_and_spelled_numbers(text):
    text += ' Le calcul est historique. La période est passée. Le risque demeure. Aucune prévision ne découle de ce calcul.'
    assert not valid_explanation(text, ['Rendement : -4,38 %.'])


def test_valid_negative_percentage_and_dates():
    text = 'Le rendement est de -4,38 %. La période va du 2025-01-01 au 2025-01-10. Le signal pédagogique invite à la prudence. Les données sont historiques. Aucun résultat futur ne peut en être déduit.'
    assert valid_explanation(text, ['-4,38 %', '2025-01-01', '2025-01-10'])
    assert percent(-.0438) == '-4,38 %'


@pytest.mark.parametrize('code,expected', [(429, 'quota'), (503, 'modèle indisponible'), (401, 'clé du modèle refusée')])
def test_failure_cause_is_safe(code, expected):
    class ProviderError(Exception):
        pass
    class BrokenModel:
        async def explain(self, *args):
            error = ProviderError('secret-key-in-provider-url')
            error.code = code
            raise error
    result = client(Settings(gemini_key='secret-key'), model=BrokenModel()).post('/chat', json={'question': 'Analyse AAPL'}).json()
    assert result['generated_by'] == 'template'
    assert expected in result['answer']
    assert expected in result['fallback_reason']
    assert 'secret-key' not in str(result)


def test_missing_key_cause():
    result = client().post('/chat', json={'question': 'Analyse AAPL'}).json()
    assert result['fallback_reason'] == 'clé du modèle absente'
    assert 'clé du modèle absente' in result['answer']


def test_relevant_corpus_only():
    result = client().post('/chat', json={'question': 'Qu’est-ce qu’un ETF ?'}).json()
    assert result['sources']
    assert all(source['file'] == 'glossaire.md' for source in result['sources'])
    result = client().post('/chat', json={'question': 'Analyse AAPL'}).json()
    assert len(result['sources']) == 1
    assert result['sources'][0]['provider'] == 'Twelve Data'


def test_adapter_sends_only_formatted_facts(monkeypatch):
    import asyncio
    import json
    from types import SimpleNamespace
    from google import genai
    from app.chat import Gemini
    captured = {}
    class FakeSDK:
        def __init__(self, **kwargs):
            self.aio = self
            self.models = self
        async def __aenter__(self):
            return self
        async def __aexit__(self, *args):
            pass
        async def generate_content(self, **kwargs):
            captured.update(kwargs)
            return SimpleNamespace(text='Texte rédigé par le modèle.')
    monkeypatch.setattr(genai, 'Client', FakeSDK)
    facts = ['Rendement sur 5 séances : -4,38 %.']
    output = asyncio.run(Gemini().explain(Settings(gemini_key='fake'), facts, {'raw': -.0438}, []))
    assert output == 'Texte rédigé par le modèle.'
    payload = json.loads(captured['contents'])
    assert payload == {'faits_formates': facts, 'passages': []}
    assert '-0.0438' not in captured['contents']
    assert '5 à 8 phrases' in captured['config'].system_instruction
