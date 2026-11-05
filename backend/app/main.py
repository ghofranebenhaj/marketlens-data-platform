import asyncio
from fastapi import FastAPI, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, ConfigDict
from starlette.exceptions import HTTPException
from . import config as c
from .calculations import indicators, signal, scenario
from .history import History, Unavailable
from .knowledge import Corpus
from .chat import Chat


class Question(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    question: str = Field(min_length=1, max_length=500)


def create_app(settings=None, history=None, model=None):
    settings = settings or c.Settings.load()
    history = history or History(settings)
    chat = Chat(history, Corpus(), settings, model)
    app = FastAPI(title='MarketLens — Assistant pédagogique')

    @app.exception_handler(HTTPException)
    async def http_error(request: Request, exc: HTTPException):
        return JSONResponse(status_code=exc.status_code, content=chat.response('Route ou méthode indisponible.'))

    @app.exception_handler(Unavailable)
    async def unavailable(request: Request, exc: Unavailable):
        return JSONResponse(status_code=503, content=chat.response(str(exc)))

    @app.exception_handler(RequestValidationError)
    async def invalid(request: Request, exc: RequestValidationError):
        return JSONResponse(status_code=422, content=chat.response('Question de 1 à 500 caractères ou paramètres entiers valides requis.'))

    @app.get('/health')
    async def health():
        return {'status': 'ok', 'history_configured': bool(settings.twelve_key),
                'model_configured': bool(settings.gemini_key), 'disclaimer': c.DISCLAIMER}

    async def calculate(symbol, kind, quantity=1, sessions=1):
        if symbol not in c.SYMBOLS:
            return JSONResponse(status_code=404, content=chat.response('Symbole inconnu du catalogue.'))
        points, source = await history.get(symbol)
        data = indicators(points) if kind == 'indicators' else signal(points) if kind == 'signal' else scenario(points, quantity, sessions)
        return {'data': data, 'sources': [source], 'disclaimer': c.DISCLAIMER}

    @app.get('/assets/{symbol}/indicators')
    async def get_indicators(symbol: str):
        return await calculate(symbol, 'indicators')

    @app.get('/assets/{symbol}/signal')
    async def get_signal(symbol: str):
        return await calculate(symbol, 'signal')

    @app.get('/assets/{symbol}/scenario')
    async def get_scenario(symbol: str, quantity: int = Query(ge=1, le=1000000), sessions: int = Query(ge=1, lt=c.WINDOW)):
        return await calculate(symbol, 'scenario', quantity, sessions)

    @app.post('/chat')
    async def post_chat(body: Question):
        try:
            return await asyncio.wait_for(chat.reply(body.question), c.CHAT_TIMEOUT)
        except TimeoutError:
            raise Unavailable('Assistant indisponible : délai de réponse dépassé.') from None

    return app


app = create_app()
