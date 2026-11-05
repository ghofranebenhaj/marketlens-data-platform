import os
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SYMBOLS = ('AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'TSLA')
ANNUAL_SESSIONS = 252
WINDOW = 100
VOLATILITY_LIMIT = 0.40
DRAWDOWN_LIMIT = -0.15
POSITIVE_WEIGHT = 1
RISK_WEIGHT = -1
FAVORABLE_SCORE = 2
CAUTION_SCORE = -1
SIGNAL_FORMULA = (f'+{POSITIVE_WEIGHT} si rendement20 > 0 ; +{POSITIVE_WEIGHT} si clôture > SMA50 ; '
                  f'{RISK_WEIGHT} si volatilité > {VOLATILITY_LIMIT} ; {RISK_WEIGHT} si drawdown < {DRAWDOWN_LIMIT}')
CACHE_SECONDS = 43200
REQUEST_TIMEOUT = 10
CHAT_TIMEOUT = 40
MODEL_TIMEOUT = 15
RETRIES = 2
DISCLAIMER = 'Simulation pédagogique, pas un conseil financier.'


@dataclass(frozen=True)
class Settings:
    twelve_key: str = ''
    gemini_key: str = ''
    model: str = 'gemini-3.6-flash'
    require_llm: bool = False

    @classmethod
    def load(cls):
        # Petit format KEY=value : pas d'expansion, pas d'exécution de shell.
        values = {}
        file = ROOT / '.env'
        if file.exists():
            for line in file.read_text(encoding='utf-8-sig').splitlines():
                if line.strip() and not line.lstrip().startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    values[key.strip()] = value.strip().strip('\"\'')
        def get(key, default=''):
            return os.environ.get(key, values.get(key, default))
        return cls(get('TWELVEDATA_KEY'), get('GEMINI_API_KEY'),
                   get('GEMINI_MODEL', 'gemini-3.6-flash'),
                   get('REQUIRE_LLM', 'false').lower() == 'true')
